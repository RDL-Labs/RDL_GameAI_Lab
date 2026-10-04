"""Opt-in layered-body bridge to the existing HarvestCampaign exploration stack."""
from copy import deepcopy
from math import ceil, hypot
import json
from pathlib import Path

from runtime.exploration import require
from runtime.layered_body import initial, capabilities, step, validate
from .world import World, segment_hit
from .timed_harvest import HarvestAgent, HarvestCampaign
from .visible_food_obstacle import sight_blocked


class BodyAgent(HarvestAgent):
    crossing_enabled = True

    def body_capabilities(self,p,action='climb'):
        b=p['locomotor'];e=b.get('energy',{})
        resistance=(next(s['resistance'] for s in e['samples'] if s['angle']==0)
                    if e and action=='walk' else e.get('climb_resistance',1))
        return capabilities(b['state'],e.get('load',0),resistance if resistance is not None else 10.)

    def sleep_rest_credit(self, previous, result, current):
        # Count the confirmed one-second wait, not the gap after completion.
        return min(1_000_000, result['executed_us']-previous['capture_us'])

    def body_candidate(self,p,action):
        if action[0]!='move':return action
        cap=self.body_capabilities(p,'walk')
        return ['move',cap['walk_distance']] if cap['can_walk'] else ['wait',0]

    def _body_final(self,d):
        if d['body_bridge']['baseline_action'][0]!=d['action'][0]:
            # Never credit the superseded method/route for a different operation.
            if d.get('continuous_selection'):
                d['continuous_selection'].pop('trial',None)
                d['continuous_selection'].pop('pending',None)
                d['continuous_selection']['superseded_by_body']=True
            if d.get('nested_models'):d['nested_models'].pop('trial',None)
            if d.get('relation_field'):d['relation_field'].update(applied=False,pending_step=False,owner=None)
            if d.get('directional_routes'):
                rs=d['directional_routes'];rs.update(applied=False,active=None,trial_complete=False)
                rs['outbound']['overflow']=True
                if rs['trip']:
                    if rs['trip']['outbound']:rs['trip']['outbound']['overflow']=True
                    rs['trip']['inbound']['overflow']=True
        return d

    def _packet(self, p):
        b = p['locomotor']
        require(set(b) == {'source', 'state', 'front_height_upper'} | ({'energy'} if getattr(self,'energy_enabled',False) else set()), 'locomotor_fields')
        if 'energy' in b:
            from runtime.energy_connection import validate_energy
            validate_energy(b)
        require(b['source'] == {k:p[k] for k in ('agent_id','observation_id','capture_us','pose_ref')}, 'locomotor_binding')
        validate(b['state'])
        h=b['front_height_upper']
        require(h is None or (type(h) in (int,float) and 0 <= h <= 20), 'barrier_height')
        return super()._packet({k:v for k,v in p.items() if k != 'locomotor'})

    def expiry(self, capture_us):
        # One-second body action must finish inside its current day phase.
        from runtime.landmark_day_cycle import DAY_US, BOUNDARIES
        boundary=next(capture_us//DAY_US*DAY_US+x for x in BOUNDARIES if x>capture_us%DAY_US)
        return min(capture_us+1_500_000, boundary, self.limit_us)

    def result_contract(self, command):
        allowed,_=super().result_contract(command)
        allowed['climb']={'moved','blocked','body_limited'}
        allowed['move'].add('body_limited')
        return allowed, command['amount'] if command['kind'] in ('move','climb') else 0

    def _decision(self,p):
        d=super()._decision(p)
        b=p['locomotor']; cap=self.body_capabilities(p)
        d['body_bridge']=dict(baseline_action=list(d['action']), baseline_reason=d['reason'], applied=False)
        if p['capture_us']+1_000_000 >= self.expiry(p['capture_us']):
            d.update(action=['wait',0],target='',reason='body_phase_boundary')
            return self._body_final(d)
        # No override of night/return, hazard, inventory or non-corresponding body.
        previous=next(reversed(self.observations.values())) if self.observations else None
        result=self.results.get('op:'+previous['observation_id']) if previous else None
        linked=previous is None or (result is not None and result['after_pose_ref']==p['pose_ref']
            and result['after_revision']==p['body_revision'] and result['executed_us']<p['capture_us'])
        food=[f for f in p['food']['visible'] if f['appearance']==self.teaching['appearance']
              and f['forward']>0 and abs(f['right'])<.1]
        eligible=(self.crossing_enabled and linked and d['day_cycle']['phase']=='exploration'
                  and d.get('terrain_gate')!='safety' and self.carried_count()==0
                  and p['food']['coverage']=='complete' and bool(food)
                  and (d['action'][0] in ('move','pickup') or d['reason']=='acquisition_incomplete'))
        h=b['front_height_upper']
        if eligible and h is not None and h>0 and h<=cap['climb_height']:
            action=['climb',cap['climb_distance']] if cap['can_climb'] else ['wait',0]
            d.update(action=action,target='',reason='observed_low_barrier_cross' if action[0]=='climb' else 'body_recovery_before_cross')
            d['body_bridge']['applied']=True
        elif d['action'][0]=='move':
            cap=self.body_capabilities(p,'walk')
            if cap['can_walk']: d['action']=['move',cap['walk_distance']]
            else: d.update(action=['wait',0],target='',reason='body_recovery_before_walk')
        return self._body_final(d)


class BodyCampaign(HarvestCampaign):
    agent_type=BodyAgent


class ExplorationBodyWorld(World):
    def carried_load(self,aid):return 0.

    def resistance(self,aid,angle=0,action='walk'):return 1.

    def __init__(self,run_id,**kwargs):
        super().__init__(run_id,**kwargs)
        self.bodies={aid:initial() for aid in self.agents}
        self.body_log={}
        self.ready_us={aid:0 for aid in self.agents}

    def visible(self,aid,obj):
        a=self.agents[aid]
        return not any(sight_blocked((a['x'],a['z']),(obj['x'],obj['z']),o) for o in self.objects)

    def packet(self,aid,slot):
        p=super().packet(aid,slot); a=self.agents[aid]; dx,dz=self.direction(aid)
        end=(a['x']+dx,a['z']+dz)
        hits=[o for o in self.objects if o['solid'] and segment_hit((a['x'],a['z']),end,o,.2)]
        p['locomotor']=dict(source={k:p[k] for k in ('agent_id','observation_id','capture_us','pose_ref')},
                           state=deepcopy(self.bodies[aid]),
                           front_height_upper=max((ceil(o['height']*10)/10 for o in hits),default=0.))
        return p

    def execute(self,c,p,executed_us=None):
        aid=c['agent_id'];op=c['operation_id'];a=self.agents[aid]
        require(all(c.get(k)==v for k,v in self.context(aid).items()),'context')
        require(c['source_id']==p['observation_id'] and op=='op:'+p['observation_id']
                and p['agent_id']==aid,'source_binding')
        require(all(c[k]==p[k] for k in ('capture_us','pose_ref','body_revision')),'capture_binding')
        if op in self.effects:
            old,r=self.effects[op];require(old==c,'operation_conflict');return deepcopy(r)
        start=c['capture_us'];now=start+1_000_000 if executed_us is None else executed_us
        require(now==start+1_000_000 and start>=self.ready_us[aid],'body_schedule')
        before=self.pose(aid);revision=a['revision'];body=deepcopy(self.bodies[aid]);distance=0.;yaw=0
        if c['pose_ref']!=before or c['body_revision']!=revision: status='stale'
        elif now>=c['expires_us']: status='expired'
        elif c['kind'] in ('move','climb'):
            action='walk' if c['kind']=='move' else 'climb'
            load=self.carried_load(aid);resistance=self.resistance(aid,action=action)
            cap=capabilities(body,load,resistance)
            require(c['amount']==cap[action+'_distance'],'body_distance')
            dx,dz=self.direction(aid);end=(a['x']+dx*c['amount'],a['z']+dz*c['amount'])
            hits=[o for o in self.objects if o['solid'] and segment_hit((a['x'],a['z']),end,o,.2)]
            clear=not hits if action=='walk' else all(o['height']<=cap['climb_height'] and not segment_hit(end,end,o,.2) for o in hits)
            self.bodies[aid],effect=step(body,action,unobstructed=clear,load=load,resistance=resistance)
            status='moved' if effect['status']=='performed' else effect['status'];distance=effect['distance']
            if distance:a['x'],a['z']=end
        elif c['kind']=='wait':
            self.bodies[aid],_=step(body,'rest');status='waited'
        elif c['kind']=='turn':
            yaw=c['amount'];a['yaw']=(a['yaw']+yaw+180)%360-180;status='turned'
        elif c['kind']=='pickup':
            status='not_found';index=self.tokens[aid].get(c['target_ref'])
            if index is not None and c['target_ref'] in {f['ref'] for f in p['food']['visible']}:
                obj=self.resources[index]
                clear=not any(o['solid'] and segment_hit((a['x'],a['z']),(obj['x'],obj['z']),o) for o in self.objects)
                if obj['stock'] and hypot(obj['x']-a['x'],obj['z']-a['z'])<=1.25 and clear and self.visible(aid,obj):
                    if not self.inexhaustible: obj['stock']-=1
                    a['inventory']+=1;status='picked_up'
                    self.pickups.append(dict(agent_id=aid,operation_id=op,executed_us=now))
        else: raise ValueError('body_kind')
        if status in ('moved','turned','picked_up'):a['revision']+=1
        r=dict(self.context(aid),operation_id=op,source_id=c['source_id'],executed_us=now,
               before_pose_ref=before,after_pose_ref=self.pose(aid),before_revision=revision,after_revision=a['revision'],
               status=status,forward=distance,right=0,up=0,yaw=yaw,acquired=status=='picked_up')
        self.effects[op]=(deepcopy(c),deepcopy(r));self.ready_us[aid]=now
        self.body_log[op]=dict(before=body,after=deepcopy(self.bodies[aid]))
        if status=='waited' and c.get('reason')=='return_unload_attempt' and hypot(a['x'],a['z']-6)<=1.25:
            fresh=[e['operation_id'] for e in self.pickups if e['agent_id']==aid and e['operation_id'] not in self.counted]
            if fresh:
                self.counted.update(fresh)
                self.returns.append(dict(agent_id=aid,day=start//64_000_000+1,pickups=fresh,executed_us=now))
                a['inventory']-=len(fresh)
        return r


class BodyScheduler:
    """World keeps advancing/observing during all one-second body operations."""
    def __init__(self,world):
        self.world=world;self.pending={};self.completed={}

    def start(self,c,p):
        aid=c['agent_id'];op=c['operation_id']
        if op in self.completed:
            require(self.completed[op][0]==c,'operation_conflict');return False
        if aid in self.pending:
            old,q,_=self.pending[aid]
            require(old==c and q==p,'body_busy');return False
        require(c['source_id']==p['observation_id'] and c['agent_id']==p['agent_id'],'source_binding')
        require(c['capture_us']>=self.world.ready_us[aid],'body_schedule')
        self.pending[aid]=(deepcopy(c),deepcopy(p),c['capture_us']+1_000_000)
        return True

    def advance(self,now):
        out=[]
        for aid,(c,p,due) in sorted(list(self.pending.items()),key=lambda item:(item[1][2],item[0])):
            if due>now:continue
            r=self.world.execute(c,p,executed_us=due)
            self.completed[c['operation_id']]=(c,deepcopy(r));del self.pending[aid]
            out.append((p,c,r))
        return out


def run_case(enabled=True,burst=10.,height=.4):
    run='body-exploration';w=ExplorationBodyWorld(run);loop=BodyCampaign(run,1)
    w.objects=[] if height is None else [dict(x=0.,z=.5,radius=.1,height=height,solid=True,color='gray')]
    w.resources=[dict(x=0.,z=1.8,stock=1)]
    w.agents['npc_a'].update(x=0.,z=0.,yaw=0.);w.bodies['npc_a']['burst']=burst
    loop.agents['npc_a'].crossing_enabled=enabled
    loop.configure(dict(w.context('npc_a'),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',
                        teaching=dict(statement_id='teaching',source='god_statue',sample_observation='sample',
                                      appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
    records=[]; acquired_before=False
    for slot in range(8,120,8):
        p=w.packet('npc_a',slot);c=loop.observe(p)['command'];r=w.execute(c,p);ack=loop.result(r)
        records.append(dict(packet=p,command=c,result=r,receipt=ack,body=w.body_log[c['operation_id']]))
        # One following observation lets the existing learning intake see the receipt.
        if acquired_before:break
        acquired_before=r['acquired']
    a=loop.agents['npc_a']
    return dict(enabled=enabled,burst=burst,height=height,records=records,
                acquired=len(w.pickups),learning_records=len(a.learning['records']),
                runtime_results=len(a.results),inventory=w.agents['npc_a']['inventory'])


def experiment():
    return {name:run_case(**args) for name,args in dict(disabled=dict(enabled=False),
        enabled={},recover=dict(burst=0.),too_high=dict(height=.7)).items()}


if __name__=='__main__':
    report=experiment()
    Path('tests/fixtures/body_exploration.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print({k:(v['acquired'],v['learning_records'],[(r['command']['kind'],r['result']['status']) for r in v['records']]) for k,v in report.items()})
