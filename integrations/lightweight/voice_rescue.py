"""Finite opt-in rescue experiment on EnergyWorld; not the exploration scheduler."""
from copy import deepcopy
from math import atan2,degrees,hypot
from threading import RLock
from runtime.layered_body import capabilities,step
from .energy_exploration import EnergyWorld
from .world import segment_hit


class RescueWorld(EnergyWorld):
    contact_distance=.6
    def __init__(self,run_id='voice-rescue'):
        super().__init__(run_id)
        self.seconds=0;self.calls=[];self.rescue_receipts={};self.rescue_lock=RLock()

    def observe_rescue(self,aid):
        a=self.agents[aid];heard=[];near=[]
        for call in self.calls:
            if call['speaker']==aid or not 0<=self.seconds-call['time']<2:continue
            dx,dz=call['x']-a['x'],call['z']-a['z'];distance=hypot(dx,dz)
            if distance>8:continue
            if any(o['solid'] and segment_hit((a['x'],a['z']),(call['x'],call['z']),o,0.) for o in self.objects):continue
            angle=(degrees(atan2(dx,dz))-a['yaw']+180)%360-180
            heard.append(dict(kind='help_call',azimuth=round(angle/30)*30,
                              range_band='near' if distance<=1 else 'far',capture_s=self.seconds))
        for other,b in self.agents.items():
            if other==aid or hypot(b['x']-a['x'],b['z']-a['z'])>self.contact_distance:continue
            if any(o['solid'] and segment_hit((a['x'],a['z']),(b['x'],b['z']),o,0.) for o in self.objects):continue
            near.append(dict(ref=other,requesting_help=any(c['speaker']==other and
                0<=self.seconds-c['time']<2 for c in self.calls)))
        return dict(body=deepcopy(self.bodies[aid]),load=self.carried_load(aid),
                    inventory=a['inventory'],heard=heard,near=near)

    def act_rescue(self,aid,operation,action,target=None,angle=0):
        with self.rescue_lock:
            key=(aid,operation);request=(action,target,angle)
            if key in self.rescue_receipts:
                old,result=self.rescue_receipts[key]
                if old!=request:raise ValueError('rescue_operation_conflict')
                return deepcopy(result)
            if action not in ('call','walk','turn','rest','feed'):raise ValueError('rescue_action')
            a=self.agents[aid];before=deepcopy(self.bodies[aid]);status='unavailable';distance=0.
            if action=='feed':
                contacts=self.observe_rescue(aid)['near']
                if a['inventory']>0 and any(c['ref']==target and c['requesting_help'] for c in contacts):
                    self.bodies[target],_=step(self.bodies[target],'eat',food_available=True)
                    a['inventory']-=1;status='fed'
            elif action=='call':
                # Finite initial vocal ability, independent of locomotion reserve.
                self.calls=[c for c in self.calls if c['speaker']!=aid and self.seconds-c['time']<2]
                self.calls.append(dict(speaker=aid,time=self.seconds,x=a['x'],z=a['z']))
                status='called'
            elif action=='turn':
                if angle not in range(-180,181,30):raise ValueError('rescue_angle')
                a['yaw']=(a['yaw']+angle+180)%360-180;status='turned'
            else:
                load=self.carried_load(aid);resistance=self.resistance(aid) if action=='walk' else 1.
                length=capabilities(before,load,resistance)['walk_distance'];dx,dz=self.direction(aid)
                end=(a['x']+dx*length,a['z']+dz*length)
                clear=not any(o['solid'] and segment_hit((a['x'],a['z']),end,o,.2) for o in self.objects)
                self.bodies[aid],r=step(before,action,load=load,resistance=resistance,unobstructed=clear)
                status=r['status'];distance=r['distance']
                if distance:a['x'],a['z']=end
            if distance or action=='turn' or status=='fed':a['revision']+=1
            result=dict(agent=aid,operation=operation,action=action,status=status,distance=distance,
                        before=before,after=deepcopy(self.bodies[aid]),time=self.seconds)
            self.rescue_receipts[key]=(request,deepcopy(result))
            return result


def choose(observation):
    """Fixed initial help preference; no knowledge of source positions or future cost."""
    if not capabilities(observation['body'],observation['load'])['can_walk']:
        return dict(action='call')
    contact=next((c for c in observation['near'] if c['requesting_help']),None)
    if contact and observation['inventory']>0:return dict(action='feed',target=contact['ref'])
    if observation['heard'] and observation['inventory']>0:
        sound=observation['heard'][0]
        return dict(action='turn',angle=sound['azimuth']) if sound['azimuth'] else dict(action='walk')
    return dict(action='rest')


def experiment(reserve=100.,distance=2.,wall=False):
    w=RescueWorld();w.objects=[]
    for i,a in enumerate(w.agents.values()):a.update(x=30.+i,z=30.,inventory=0,yaw=0.)
    w.agents['npc_a'].update(x=0.,z=0.,inventory=1)
    w.agents['npc_b'].update(x=0.,z=distance)
    w.bodies['npc_a']['reserve']=reserve;w.bodies['npc_b']['reserve']=0.
    if wall:w.objects=[dict(x=0.,z=distance/2,radius=.2,height=2.,solid=True)]
    records=[]
    for t in range(12):
        w.seconds=t
        for aid in ('npc_b','npc_a'):
            observation=w.observe_rescue(aid);decision=choose(observation)
            result=w.act_rescue(aid,f'{t}:{aid}',**decision)
            records.append(dict(observation=observation,decision=decision,result=result))
    return dict(records=records,fed=sum(r['result']['status']=='fed' for r in records),
                bodies=w.bodies,inventory={a:b['inventory'] for a,b in w.agents.items()},
                unable_to_walk=[a for a in ('npc_a','npc_b') if not capabilities(w.bodies[a],w.carried_load(a))['can_walk']])


if __name__=='__main__':
    import json
    from pathlib import Path
    results=dict(rescued=experiment(),rescuer_stranded=experiment(reserve=.15),
                 inaudible=experiment(distance=9),occluded=experiment(wall=True))
    Path('tests/fixtures/voice_rescue.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf8')
    print({k:dict(fed=v['fed'],unable=v['unable_to_walk']) for k,v in results.items()})
