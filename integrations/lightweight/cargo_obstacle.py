"""Finite cargo/obstacle interaction experiment; shares layered body and geometry."""
from copy import deepcopy
import json
from pathlib import Path
from runtime.layered_body import capabilities, step
from .body_fixture import BodyWorld
from .world import segment_hit


class CargoWorld(BodyWorld):
    def __init__(self,stock=6):
        super().__init__()
        for aid in self.world.agents:self.world.agents[aid].update(x=0.,z=0.,yaw=0.,inventory=0)
        self.world.objects=[dict(x=0.,z=.5,radius=.1,height=.4,solid=True)]
        self.world.resources=[dict(x=0.,z=0.,stock=stock,unit_weight=1.)]
        self.cargo={aid:[] for aid in self.world.agents}

    def observe(self,aid):
        a=self.world.agents[aid];dx,dz=self.world.direction(aid)
        hits=[o for o in self.world.objects if segment_hit((a['x'],a['z']),(a['x']+dx,a['z']+dz),o,.2)]
        return dict(body=deepcopy(self.states[aid]),weights=list(self.cargo[aid]),
                    front_height=max((o['height'] for o in hits),default=0.))

    def execute_cargo(self,aid,op,action):
        with self.lock:
            request=(aid,action);key=(aid,op)
            if key in self.receipts:
                old,r=self.receipts[key]
                if old!=request:raise ValueError('cargo_conflict')
                return deepcopy(r)
            if action not in ('pickup','drop','climb','walk','rest','detour'):raise ValueError('cargo_action')
            a=self.world.agents[aid];before=self.observe(aid);start=self.clock[aid]
            status='unavailable';distance=0.;item=None
            if action=='pickup':
                pile=next((p for p in self.world.resources if p['stock']>0 and
                           (p['x']-a['x'])**2+(p['z']-a['z'])**2<=.25**2),None)
                if pile:
                    item=pile['unit_weight'];pile['stock']-=1;self.cargo[aid].append(item);status='picked_up'
            elif action=='drop':
                if self.cargo[aid]:
                    item=self.cargo[aid].pop()
                    self.world.resources.append(dict(x=a['x'],z=a['z'],stock=1,unit_weight=item))
                    status='dropped'
            else:
                body_action='walk' if action=='detour' else action
                load=sum(self.cargo[aid]);cap=capabilities(self.states[aid],load)
                dx,dz=self.world.direction(aid,90 if action=='detour' else 0)
                length=cap.get(body_action+'_distance',0.)
                end=(a['x']+dx*length,a['z']+dz*length)
                hits=[o for o in self.world.objects if segment_hit((a['x'],a['z']),end,o,.2)]
                clear=not hits if body_action!='climb' else all(o['height']<=cap['climb_height']+1e-12
                    and not segment_hit(end,end,o,.2) for o in hits)
                self.states[aid],result=step(self.states[aid],body_action,load=load,unobstructed=clear)
                status=result['status'];distance=result['distance']
                if distance:a['x'],a['z']=end
            a['inventory']=len(self.cargo[aid]);self.clock[aid]+=1_000_000
            if distance or status in ('picked_up','dropped'):a['revision']+=1
            r=dict(agent_id=aid,operation_id=op,action=action,status=status,start_us=start,
                   end_us=self.clock[aid],before=before,after=self.observe(aid),distance=distance,item_weight=item)
            self.receipts[key]=(request,deepcopy(r));return r

    def audit(self):
        return dict(carried=sum(map(len,self.cargo.values())),ground=sum(p['stock'] for p in self.world.resources),
                    total_weight=sum(sum(c) for c in self.cargo.values())+sum(p['stock']*p['unit_weight'] for p in self.world.resources))


def select(observation,goal,detour_observed=False):
    """Initial local preferences, not learned ownership, danger inference or routing."""
    if goal not in ('return','escape'):raise ValueError('cargo_goal')
    state=observation['body'];weights=observation['weights'];h=observation['front_height']
    cap=capabilities(state,sum(weights));candidates=[]
    def add(action,cost,reason):candidates.append(dict(action=action,cost=cost,reason=reason))
    if h<=cap['climb_height']+1e-12:
        if cap['can_climb']:add('climb',.2,'current_load_clearable')
        else:add('rest',.3,'body_recovery_needed')
    if weights and h>cap['climb_height']+1e-12:
        add('drop',.1 if goal=='escape' else .7,'reduce_load_constraint')
    if detour_observed and cap['can_walk']:add('detour',.4,'observed_side_step')
    add('rest',2.,'hold_and_recover')
    chosen=min(candidates,key=lambda c:(c['cost'],c['action']))
    return dict(goal=goal,load=sum(weights),climb_height=cap['climb_height'],
                obstacle_pressure=h/cap['climb_height'] if cap['climb_height'] else None,
                candidates=candidates,selected=chosen['action'])


def run_case(count,goal='return',detour=False,tired=False):
    w=CargoWorld(count);aid='npc_a';records=[]
    for i in range(count):records.append(w.execute_cargo(aid,f'collect:{i}','pickup'))
    # Experimental initial tired condition, not inferred from the pickup sequence.
    if tired:w.states[aid]['burst']=0.
    decisions=[]
    for i in range(8):
        d=select(w.observe(aid),goal,detour);decisions.append(d)
        r=w.execute_cargo(aid,f'trial:{i}',d['selected']);records.append(r)
        if r['distance']>0:break
    return dict(count=count,goal=goal,detour_observed=detour,tired=tired,decisions=decisions,records=records,audit=w.audit())


def experiment():
    return {name:run_case(**settings) for name,settings in dict(
        five=dict(count=5),six=dict(count=6),six_tired=dict(count=6,tired=True),
        return_detour=dict(count=6,detour=True),escape_detour=dict(count=6,goal='escape',detour=True)).items()}


if __name__=='__main__':
    report=experiment()
    Path('tests/fixtures/cargo_obstacle.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print({k:[d['selected'] for d in v['decisions']] for k,v in report.items()})
