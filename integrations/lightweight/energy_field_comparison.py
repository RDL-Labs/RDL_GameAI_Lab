"""Small shared-resource experiment with observed local movement resistance."""
import json
from pathlib import Path
from runtime.energy_field import evaluate
from runtime.layered_body import capabilities
from .cargo_obstacle import CargoWorld
from .world import segment_hit


class EnergyWorld(CargoWorld):
    def __init__(self,resistance=1.):
        super().__init__(6);self.world.objects=[];self.front_resistance=resistance

    def surface_resistance(self,aid,action):
        return self.front_resistance if action=='walk' else 1.

    def samples(self,aid):
        # Bounded local sensor: current swept steps only, no destination coordinates.
        a=self.world.agents[aid];rows=[]
        for action,angle,goal in (('walk',0,0.),('detour',90,.15)):
            dx,dz=self.world.direction(aid,angle)
            length=capabilities(self.states[aid],sum(self.cargo[aid]))['walk_distance']
            end=(a['x']+length*dx,a['z']+length*dz)
            clear=not any(segment_hit((a['x'],a['z']),end,o,.2) for o in self.world.objects)
            rows.append(dict(ref=f'{aid}:{self.clock[aid]}:{action}',action=action,clear=clear,
                             resistance=self.surface_resistance(aid,action),goal_cost=goal))
        return rows

    def decide(self,aid):
        return evaluate(self.states[aid],sum(self.cargo[aid]),self.samples(aid))


def run_case(resistance=1.,reserve=100.):
    w=EnergyWorld(resistance);w.states['npc_a']['reserve']=reserve
    collected=[w.execute_cargo('npc_a',f'collect:{i}','pickup') for i in range(6)]
    field=w.decide('npc_a');result=w.execute_cargo('npc_a','move',field['action'])
    return dict(field=field,result=result,collected=collected,audit=w.audit())


def interaction():
    w=EnergyWorld(5.);records=[]
    for i in range(6):records.append(w.execute_cargo('npc_a',str(i),'pickup'))
    before=w.decide('npc_a')
    # Explicit scenario trigger; dropping/approaching another's item is not learned here.
    records.append(w.execute_cargo('npc_a','drop','drop'))
    w.clock['npc_b']=w.clock['npc_a']  # Common timeline; unacted idle earns no recovery.
    records.append(w.execute_cargo('npc_b','pickup','pickup'))
    w.clock['npc_a']=w.clock['npc_b']
    records.append(w.execute_cargo('npc_a','retrieve','pickup'))
    w.clock['npc_b']=w.clock['npc_a']
    fields={aid:w.decide(aid) for aid in ('npc_a','npc_b')}
    for aid in fields:records.append(w.execute_cargo(aid,'move',fields[aid]['action']))
    return dict(before=before,fields=fields,records=records,audit=w.audit())


def experiment():
    return dict(easy=run_case(),resistive=run_case(5.),low_reserve=run_case(5.,.2),interaction=interaction())


if __name__=='__main__':
    r=experiment();Path('tests/fixtures/energy_field.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8')
    print({k:v['field']['action'] for k,v in r.items() if 'field' in v})
