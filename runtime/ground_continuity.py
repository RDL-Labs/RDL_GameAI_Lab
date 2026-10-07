"""Finite agent-relative tentative ground models; no World map or road semantics."""
from copy import deepcopy
from math import sin,cos,radians,hypot,atan2,degrees
from .ground_pattern import recognize

RULE='observed-ground-continuity-v1'
WORN={'trampled_grass','bare_ground'}


def points(p,group):
    cells=p['ground_appearance']['cells']
    return [[cells[i]['distance']*sin(radians(cells[i]['angle'])),
             cells[i]['distance']*cos(radians(cells[i]['angle']))] for i in group['sample_indices']]


def update(p,previous=None,result=None):
    patterns=recognize(p);binding=[p['run_id'],p['agent_id'],p['world_epoch'],p['clock_id']]
    s=deepcopy(previous) if previous else dict(rule=RULE,binding=binding,sequence=0,models=[])
    if s['binding']!=binding:raise ValueError('ground_model_binding')
    if s.get('source')==p['observation_id']:return s
    linked=bool(previous and result and result.get('run_id')==p['run_id'] and
        result.get('agent_id')==p['agent_id'] and result.get('source_id')==previous['source'] and
        result.get('before_pose_ref')==previous['pose_ref'] and
        result.get('before_revision')==previous['body_revision'] and
        result.get('after_pose_ref')==p['pose_ref'] and result.get('after_revision')==p['body_revision'] and
        previous['capture_us']<=result['executed_us']<p['capture_us'] and
        result['status'] not in ('stale','expired'))
    s['retired']=[];s['events']=[]
    if previous and not linked:
        s['retired']=[m['model_ref'] for m in s['models']]
        s['models']=[];s['events'].append('body_correspondence_unavailable')
    if linked:
        a=radians(result['yaw']);c=cos(a);sn=sin(a)
        for m in s['models']:
            m['pending_transforms']=(m.get('pending_transforms',[])+[dict(
                operation_id=result['operation_id'],source_id=result['source_id'],
                forward=result['forward'],right=result['right'],yaw=result['yaw'],
                before_pose_ref=result['before_pose_ref'],after_pose_ref=result['after_pose_ref'])])[-32:]
            m['points']=[[c*(x-result['right'])-sn*(z-result['forward']),
                          sn*(x-result['right'])+c*(z-result['forward'])] for x,z in m['points']]
            m['status']='not_currently_supported';m['current_points']=[]
    alive=[]
    for m in s['models']:
        if p['capture_us']-m['last_seen_us']>8_000_000:s['retired'].append(m['model_ref'])
        else:alive.append(m)
    s['models']=alive
    groups=[g for g in patterns['groups'] if g['appearance'] in WORN and g['shape']=='sampled_band_candidate']
    # Matching is conservative: two sampled overlaps and unique assignment on both sides.
    observed=[points(p,g) for g in groups]
    choices=[[i for i,m in enumerate(s['models']) if
        sum(any(hypot(x-u,z-v)<=.6 for u,v in m['points']) for x,z in ps)>=2] for ps in observed]
    used=set()
    for g,ps,options in zip(groups,observed,choices):
        unique=len(options)==1 and sum(options[0] in cs for cs in choices)==1
        if unique:
            m=s['models'][options[0]];used.add(m['model_ref'])
            m['extended']=any(all(hypot(x-u,z-v)>.25 for u,v in m['points']) for x,z in ps)
            m['links']=(m['links']+[dict(from_source=m['sources'][-1],to_source=p['observation_id'],
                transforms=m['pending_transforms'],rule='two-sampled-overlaps-with-measured-body-transform')])[-16:]
            m['pending_transforms']=[]
            m['points']=(ps+[q for q in m['points'] if all(hypot(q[0]-x,q[1]-z)>.25 for x,z in ps)])[:32]
        else:
            if options:
                s['events'].append('ambiguous_correspondence');continue
            if len(s['models'])>=8:
                s['events'].append('active_model_capacity');continue
            s['sequence']+=1
            m=dict(model_ref='ground_'+str(s['sequence']),points=ps,sources=[],links=[],pending_transforms=[],
                extended=False,interpretation='tentative-continuous-worn-ground; destination-unknown')
            s['models'].append(m);used.add(m['model_ref'])
        m.update(status='observed',current_points=ps,pattern_ref=g['pattern_ref'],last_seen_us=p['capture_us'])
        m['sources']=(m['sources']+[p['observation_id']])[-16:]
    grass=[points(p,g) for g in patterns['groups'] if g['appearance']=='grass']
    for m in s['models']:
        if m['model_ref'] in used:continue
        if sum(any(hypot(x-u,z-v)<=.6 for ps in grass for u,v in ps) for x,z in m['points'])>=2:
            m['status']='observed_context_changed'
    s.update(source=p['observation_id'],capture_us=p['capture_us'],pose_ref=p['pose_ref'],body_revision=p['body_revision'],
             coverage=patterns['coverage'],body_linked=linked)
    return s


def proposals(s,safe):
    out=[]
    for m in s['models']:
        if m['status']!='observed':continue
        # Continue toward an actually sampled endpoint; do not extrapolate hidden path.
        x,z=max(m['current_points'],key=lambda q:(hypot(*q),q[1],q[0]))
        angle=degrees(atan2(x,z))
        choices=[a for a in safe if a in (-90,-45,0,45,90) and abs(a-angle)<=22.5]
        if choices:out.append((m['model_ref'],min(choices,key=lambda a:abs(a-angle))))
    return out
