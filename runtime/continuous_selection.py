"""Per-decision local method selection. Finite candidates, no lifetime action quota."""
from copy import deepcopy
from math import cos,radians
from .nested_local_models import view

RULE='continuous-local-method-selection-v1'


def signature(p):
    return [view(p),p.get('hazard',{}).get('coverage'),p.get('hazard',{}).get('features',[])]


def review(agent,p,d):
    d=deepcopy(d)
    previous=next(reversed(agent.observations.values())) if agent.observations else None
    last=agent.decisions.get(previous['observation_id'],{}) if previous else {}
    cmd=agent.commands.get(previous['observation_id']) if previous else None
    r=agent.results.get(cmd['operation_id']) if cmd else None
    linked=bool(r and r['after_pose_ref']==p['pose_ref'] and r['after_revision']==p['body_revision']
        and r['executed_us']<p['capture_us'] and r['status'] not in ('stale','expired'))
    s=deepcopy(last.get('continuous_selection')) if last.get('continuous_selection') else dict(
        rule=RULE,binding=[p['run_id'],p['agent_id']],nodes={},events=[],sequence=0)
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('selection_binding')
    trial=s.pop('trial',None);pending=s.pop('pending',None);continuing=False
    if trial:
        n=s['nodes'][trial['model']];before=n['H'];value=None
        if linked:
            if trial['question']=='rotation_then_step':
                continuing=r['status']=='turned' and abs(r['yaw']-trial['angle'])<.01
                g=p['movement_surface']['ground']
                forward=any(x['direction_deg']==0 and x['status']=='sampled' and x['height_delta'] is not None and abs(x['height_delta'])<=.5 for x in g['samples']) and not g['output_limited']
                danger=trial['model'].startswith('safety/') and any(x['range_band']=='near' and x['azimuth'][0]<30 and x['azimuth'][1]>-30 for x in p.get('hazard',{}).get('features',[]))
                continuing=continuing and forward and not danger
                if not continuing:value=0
            elif trial['question']=='clearance_evidence':
                h=p.get('hazard',{});fs=h.get('features',[])
                before_band=trial['band'];band=min(({'near':0,'watch':1,'far':2}[x['range_band']] for x in fs),default=3)
                value=int((not fs and h.get('coverage')=='complete') or (bool(fs) and band>before_band))
            elif trial['question']=='acquired':value=int(bool(r['acquired']))
            elif trial['question']=='rested':value=int(r['status']=='waited')
            else:value=int(signature(p)!=signature(previous))
        if value is not None:n['H']=0 if value else min(32,before+1)
        s['events']=(s['events']+[dict(model=trial['model'],source=trial['source'],result_source=p['observation_id'],
            question=trial['question'],F=1,F_prime=value,E=None if value is None else 1-value,
            H_before=before,H_after=n['H'],status='pending_step' if continuing else ('defer' if value is None else 'compared'))])[-32:]
    phase=d['day_cycle']['phase'];family={'exploration':'food','return':'home','safety':'safety','night':'rest','orientation':'orientation'}[phase]
    s.update(sequence=s['sequence']+1,candidates=[],selected=None,source=p['observation_id'],baseline=dict(action=d['action'][:],reason=d['reason']),applied=False)
    d['continuous_selection']=s
    def node(name):return s['nodes'].setdefault(family+'/'+name,dict(H=0,threshold=2,last_selected=0))
    def add(name,action,priority,question):
        n=node(name)
        # Bounded soft penalty keeps every feasible method eligible, including at H saturation.
        pressure=min(2,n['H']/n['threshold'])
        s['candidates'].append(dict(model=family+'/'+name,action=action,score=priority-pressure,
            H=n['H'],threshold=n['threshold'],question=question,last_selected=n['last_selected']))
    h=p.get('hazard',{});features=h.get('features',[])
    band=min(({'near':0,'watch':1,'far':2}[x['range_band']] for x in features),default=3)
    question='clearance_evidence' if phase=='safety' else 'view_changed'
    protected=(phase in ('night','orientation') or d['action'][0]=='pickup' or d['reason'] in (
        'return_unload_attempt','return_delivery_confirmed','return_home_like_observed','finite_rest','inventory_capacity'))
    if not linked and previous is not None:
        add('await_body',['wait',0],1,'view_changed');s['gate']='body_unlinked'
    elif protected or (phase!='safety' and d['action'][0]!='wait' and node('baseline')['H']<node('baseline')['threshold']):
        q='acquired' if d['action'][0]=='pickup' else ('rested' if protected else 'view_changed')
        add('work' if q=='acquired' else ('rest' if protected else 'baseline'),d['action'][:],3,q)
        s['gate']='current_feasible_proposal'
    else:
        if phase!='safety' and d['action'][0]!='wait':add('baseline',d['action'][:],3,'view_changed')
        ground=p['movement_surface']['ground']
        safe=sorted(x['direction_deg'] for x in ground['samples'] if x['status']=='sampled' and
            x['height_delta'] is not None and abs(x['height_delta'])<=.5) if not ground['output_limited'] else []
        front_threat=any(x['range_band']=='near' and x['azimuth'][0]<30 and x['azimuth'][1]>-30 for x in features)
        if continuing and pending and pending['family']==family and 0 in safe and not (phase=='safety' and front_threat):
            add(pending['name'],['move',1],10,question);s['gate']='measured_turn_current_step'
        else:
            add('wait',['wait',0],2 if phase=='safety' and features else 1,question)
            add('survey_left',['turn',-90],1.5,question)
            add('survey_right',['turn',90],1.5,question)
            for angle in safe:
                if angle not in (-90,-45,0,45,90):continue
                if phase=='safety' and angle==0 and front_threat:continue
                priority=2
                if phase=='safety' and features:
                    # Minimax directional pressure: a second threat cannot disappear
                    # through vector cancellation or feature ordering.
                    priority=2-1.5*max(cos(radians(angle-sum(x['azimuth'])/2)) for x in features)
                add('step_'+str(angle),['move',1] if angle==0 else ['turn',angle],priority,
                    question if angle==0 else 'rotation_then_step')
            s['gate']='method_reselection'
    if getattr(agent,'sleep_auto_adopt',False):
        from .sleep_auto_model import apply
        before=min(s['candidates'],key=lambda c:(-c['score'],c['last_selected'],c['model']))['model']
        s['sleep_model']=apply(agent,p,s['candidates'])
    chosen=min(s['candidates'],key=lambda c:(-c['score'],c['last_selected'],c['model']))
    if getattr(agent,'sleep_auto_adopt',False):
        s['sleep_model'].update(baseline_selected=before,selected=chosen['model'],changed=before!=chosen['model'])
    name=chosen['model'].split('/',1)[1];n=s['nodes'][chosen['model']];n['last_selected']=s['sequence']
    s['selected']=chosen['model'];s['applied']=chosen['action']!=d['action'] or phase=='safety'
    s['trial']=dict(model=chosen['model'],question=chosen['question'],source=p['observation_id'],band=band,angle=chosen['action'][1])
    if chosen['question']=='rotation_then_step':s['pending']=dict(family=family,name=name)
    if s['applied']:
        # A superseded proposal must not later receive credit for an unexecuted action.
        if d.get('relation_field'):d['relation_field'].update(applied=False,pending_step=False,owner=None)
        if d.get('directional_routes'):
            rs=d['directional_routes'];rs.update(applied=False,active=None,trial_complete=False)
            rs['outbound']['overflow']=True
            if rs['trip']:
                if rs['trip']['outbound']:rs['trip']['outbound']['overflow']=True
                rs['trip']['inbound']['overflow']=True
        for key in ('reposition','return_reposition'):
            if d.get(key):d[key].update(applied=False,pending_step=False)
        if d.get('nested_models'):d['nested_models'].pop('trial',None)
        d.update(action=chosen['action'][:],target='',reason='continuous_'+chosen['model'],terrain_gate='continuous_selection')
        if d.get('mb_field'):d['mb_field'].update(final_action=d['action'][:],final_reason=d['reason'])
    if phase=='safety':
        prior=last.get('safety',{})
        operations=prior.get('operations',0) if prior.get('generation')==d['safety']['generation'] else 0
        d['safety'].update(action=d['action'][:],reason=d['reason'],method=s['selected'],pending_step=False,
            clearance_scan=s['selected'] in ('safety/survey_left','safety/survey_right'),
            operations=operations+int(d['action'][0] in ('move','turn')))
    return d
