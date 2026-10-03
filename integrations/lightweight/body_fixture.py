"""Explicit body commands on shared lightweight World geometry, not NPC policy."""
from copy import deepcopy
from threading import RLock
import json
from pathlib import Path
from runtime.layered_body import initial,capabilities,step
from .world import World,segment_hit


class BodyWorld:
    def __init__(self):
        self.world=World('layered-body-fixture')
        self.world.objects=[]
        self.states={aid:initial() for aid in self.world.agents}
        self.receipts={};self.clock={aid:0 for aid in self.world.agents};self.lock=RLock()

    def execute(self,agent_id,operation_id,action,start_us):
        with self.lock:
            request=(agent_id,operation_id,action,start_us)
            key=(agent_id,operation_id)
            if key in self.receipts:
                old,receipt=self.receipts[key]
                if old!=request:raise ValueError('body_operation_conflict')
                return deepcopy(receipt)
            if agent_id not in self.states or not isinstance(operation_id,str) or not operation_id:
                raise ValueError('body_identity')
            if type(start_us) is not int or start_us!=self.clock[agent_id]:
                raise ValueError('body_clock')
            a=self.world.agents[agent_id];cap=capabilities(self.states[agent_id])
            distance=cap.get(action+'_distance',0)
            dx,dz=self.world.direction(agent_id);start=(a['x'],a['z'])
            end=(start[0]+distance*dx,start[1]+distance*dz)
            hits=[o for o in self.world.objects if o['solid'] and segment_hit(start,end,o,.2)]
            clear=not hits
            if action=='climb':
                clear=all(o['height']<=cap['climb_height'] and not segment_hit(end,end,o,.2) for o in hits)
            before=deepcopy(self.states[agent_id])
            after,result=step(before,action,unobstructed=clear,food_available=a['inventory']>0)
            if result['distance']:
                a['x'],a['z']=end;a['revision']+=1
            a['inventory']-=result['food_consumed']
            self.states[agent_id]=after;self.clock[agent_id]=start_us+1_000_000
            receipt=dict(agent_id=agent_id,operation_id=operation_id,start_us=start_us,
                end_us=self.clock[agent_id],before=before,after=deepcopy(after),result=result)
            self.receipts[key]=(request,deepcopy(receipt))
            return receipt


def scenario():
    w=BodyWorld();aid='npc_a';events=[]
    def do(action):
        r=w.execute(aid,str(len(events)),action,w.clock[aid]);events.append(r);return r
    for _ in range(4):do('run')
    do('walk')
    for _ in range(5):do('rest')
    do('run')
    # Low obstruction directly ahead: walk blocked; climb reaches clear ground.
    a=w.world.agents[aid]
    w.world.objects=[dict(x=a['x'],z=a['z']+.5,radius=.1,height=.4,solid=True)]
    do('walk');do('climb')
    do('rest');do('rest')
    a=w.world.agents[aid]
    w.world.objects=[dict(x=a['x'],z=a['z']+.5,radius=.1,height=2.,solid=True)]
    do('climb')
    # Experimenter-set depleted condition, not a simulated long starvation run.
    w.world.objects=[]
    w.states[aid].update(burst=0.,strain=.8,reserve=0.)
    do('rest');do('run')
    a['inventory']=1
    do('eat');do('rest');do('rest');do('run')
    return dict(rule='layered-body-fixture-v1',events=events,
        authority='scripted body actions; depleted state and food inventory are fixture inputs; not autonomous exploration')


if __name__=='__main__':
    report=scenario()
    Path('tests/fixtures/lightweight_layered_body.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print([(x['result']['action'],x['result']['status']) for x in report['events']])
