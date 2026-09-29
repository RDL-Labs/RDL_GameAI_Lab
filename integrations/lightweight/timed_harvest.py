"""Opt-in timed harvest: fixed work duration, independent agents, result-time stock."""
from copy import deepcopy
from runtime.landmark_day_cycle import DAY_US, BOUNDARIES, phase
from runtime.landmark_return_campaign import ReturnCampaign
from .world import World, ApproachAgent

WORK_US=500_000

class HarvestAgent(ApproachAgent):
    def expiry(self,capture):
        start=capture//DAY_US*DAY_US
        boundary=next(start+b for b in BOUNDARIES if start+b>capture)
        return min(capture+WORK_US+1,boundary)

    def _decision(self,p):
        d=super()._decision(p)
        if d['action'][0]=='pickup' and p['capture_us']+WORK_US>=self.expiry(p['capture_us']):
            d.update(action=['wait',0],target='',reason='harvest_work_deadline')
        # Only bypass the combined appearance gate, never a body/life/variation gate.
        if phase(p['capture_us'])!='exploration' or d['reason']!='acquisition_incomplete':return d
        previous=next(reversed(self.observations.values())) if self.observations else None
        r=self.results.get('op:'+previous['observation_id']) if previous else None
        linked=previous is None or (r and r['after_pose_ref']==p['pose_ref'] and r['after_revision']==p['body_revision'] and r['executed_us']<p['capture_us'])
        food=[i for i in p['food']['visible'] if i['appearance']==self.teaching['appearance'] and i['distance']<=1.25]
        if linked and p['food']['coverage']=='complete' and food and p['capture_us']+WORK_US<self.expiry(p['capture_us']):
            d.update(action=['pickup',0],target=food[0]['ref'],reason='reachable_food_work',terrain_gate='pickup_work')
        return d

class HarvestCampaign(ReturnCampaign):
    agent_type=HarvestAgent

class WorkScheduler:
    def __init__(self,world):self.world=world;self.pending={};self.completed={}
    def start(self,c,p):
        aid=c['agent_id'];op=c['operation_id']
        if op in self.completed:
            old,r=self.completed[op]
            if old!=c:raise ValueError('operation_conflict')
            return False
        if aid in self.pending:
            old,q,due=self.pending[aid]
            if old!=c or q!=p:raise ValueError('body_busy')
            return False
        if c['kind']!='pickup' or c['capture_us']+WORK_US>=c['expires_us']:raise ValueError('work_deadline')
        if c['pose_ref']!=self.world.pose(aid) or c['body_revision']!=self.world.agents[aid]['revision']:raise ValueError('stale_start')
        if p['food']['coverage']!='complete' or not any(i['ref']==c['target_ref'] and i['distance']<=1.25 for i in p['food']['visible']):raise ValueError('work_target')
        self.pending[aid]=(deepcopy(c),deepcopy(p),c['capture_us']+WORK_US)
        return True
    def advance(self,now):
        out=[]
        for aid,(c,p,due) in sorted(list(self.pending.items()),key=lambda x:(x[1][2],x[0])):
            if due>now:continue
            r=self.world.execute(c,p,executed_us=due)
            self.completed[c['operation_id']]=(c,deepcopy(r));del self.pending[aid]
            out.append((p,c,r))
        return out


def run(path,days=30,skyline_subrays=False,inexhaustible=False):
    import json,time
    from pathlib import Path
    w=World('lw-work',layout='sparse');loop=HarvestCampaign(w.run_id,days,mb_field_mode='enabled',harvest_state=True)
    w.skyline_subrays=skyline_subrays
    w.inexhaustible=inexhaustible
    scheduler=WorkScheduler(w);start=time.perf_counter();captures=0
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('w',encoding='utf8') as f:
        def emit(x):f.write(json.dumps(x,separators=(',',':'))+'\n');f.flush()
        emit(dict(type='manifest',version='lw-timed-harvest-v1',days=days,stock_mode='inexhaustible' if inexhaustible else 'finite',work_us=WORK_US,skyline_subrays=skyline_subrays,objects=w.objects,resources=w.resources,agents=w.agents,seed=w.seed))
        for aid in w.agents:
            loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id=aid+':teaching',source='god_statue',sample_observation=aid+':sample',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        def complete(p,c,r):
            loop.result(r)
            emit(dict(type='completed',packet=p,command=c,result=r,body=w.agents[c['agent_id']],stock=[x['stock'] for x in w.resources]))
        for slot in range(days*256):
            now=slot*250000
            finished=set()
            for p,c,r in scheduler.advance(now):complete(p,c,r);finished.add(c['agent_id'])
            packets={aid:w.packet(aid,slot) for aid in w.agents}
            for aid,p in packets.items():
                captures+=1
                if aid in scheduler.pending or aid in finished:
                    emit(dict(type='working_capture',packet=p,reason='body_busy' if aid in scheduler.pending else 'completion_boundary'))
                    continue
                c=loop.observe(p)['command'];d=loop.agents[aid].decisions[p['observation_id']]
                emit(dict(type='decision',packet=p,command=c,model_ref=d['model_ref'],records=len(loop.agents[aid].learning['records'])))
                if c['kind']=='pickup':
                    scheduler.start(c,p);emit(dict(type='work_started',agent_id=aid,operation_id=c['operation_id'],start_us=now,due_us=now+WORK_US))
                else:complete(p,c,w.execute(c,p))
            if len(w.returns)>=3 and not scheduler.pending:break
        assert not scheduler.pending
        ended=(slot+1)*250000;reason='return_target_reached' if len(w.returns)>=3 else 'time_limit'
        for aid in w.agents:loop.finish(dict(w.context(aid),ended_us=ended,reason=reason))
        summary=dict(type='summary',reason=reason,captures=captures,ended_us=ended,pickups=len(w.pickups),returns=w.returns,elapsed_seconds=time.perf_counter()-start,stock=[x['stock'] for x in w.resources],
            agents={aid:dict(observations=len(a.observations),records=len(a.learning['records']),model_ref=a.model.model_ref if a.model else None) for aid,a in loop.agents.items()})
        emit(summary)
    return summary

if __name__=='__main__':
    import argparse,json
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--days',type=int,default=30);p.add_argument('--skyline-subrays',action='store_true');p.add_argument('--inexhaustible',action='store_true');a=p.parse_args()
    print(json.dumps(run(a.output,a.days,a.skyline_subrays,a.inexhaustible),indent=2))
