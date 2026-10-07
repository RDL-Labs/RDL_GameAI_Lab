"""Opt-in body World with shared spatial resistance strips and unit-weight food."""
from math import floor
from .body_exploration import ExplorationBodyWorld,BodyAgent,BodyCampaign
from .world import segment_hit
from runtime.layered_body import capabilities
from runtime.energy_connection import ANGLES


class EnergyAgent(BodyAgent):
    energy_enabled=True
    ground_pattern_enabled=False

    def _decision(self,p):
        d=super()._decision(p)
        if self.ground_pattern_enabled and 'ground_appearance' in p:
            from runtime.ground_pattern import recognize
            d['ground_patterns']=recognize(p)
        return d

    def _packet(self,p):
        if 'ground_appearance' in p:
            from .ground_appearance import validate
            validate(p['ground_appearance'],p)
        return super()._packet({k:v for k,v in p.items() if k!='ground_appearance'})


class EnergyCampaign(BodyCampaign):
    agent_type=EnergyAgent


class EnergyWorld(ExplorationBodyWorld):
    ground_wear_enabled=False
    ground_appearance_enabled=False
    ordinary_resistance=1.5
    difficult_resistance=5.

    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        from .ground_wear import GroundWear
        self.ground_wear=GroundWear()

    def execute(self,c,p,executed_us=None):
        a=self.agents[c['agent_id']];start=(a['x'],a['z'])
        replay=c['operation_id'] in self.effects
        result=super().execute(c,p,executed_us)
        if self.ground_wear_enabled and not replay and c['kind']=='move' and result['status']=='moved':
            self.ground_wear.walk(c['operation_id'],c['agent_id'],start,(a['x'],a['z']))
        return result

    def carried_load(self,aid):
        return float(self.agents[aid]['inventory'])

    def resistance(self,aid,angle=0,action='walk'):
        a=self.agents[aid];dx,dz=self.direction(aid,angle)
        distance=capabilities(self.bodies[aid],self.carried_load(aid))[action+'_distance']
        # Fixed local material strips; no destination, agent ID or success labels.
        base=self.difficult_resistance if floor((a['x']+dx*distance/2)/2)%2 else self.ordinary_resistance
        if hasattr(self,'landscape'):
            x,z=a['x']+dx*distance/2,a['z']+dz*distance/2
            base=self.landscape.resistance(x,z)
            if not self.landscape.dry(x,z):return base
        if self.ground_wear_enabled and action=='walk':
            return 1+(base-1)*self.ground_wear.factor(a['x']+dx*distance/2,a['z']+dz*distance/2)
        return base

    def packet(self,aid,slot):
        p=super().packet(aid,slot);a=self.agents[aid];samples=[]
        distance=capabilities(self.bodies[aid],self.carried_load(aid))['walk_distance']
        for angle in ANGLES:
            dx,dz=self.direction(aid,angle)
            clear=not any(o['solid'] and segment_hit((a['x'],a['z']),
                (a['x']+dx*distance,a['z']+dz*distance),o,.2) for o in self.objects)
            samples.append(dict(angle=angle,clear=clear,resistance=self.resistance(aid,angle)))
        p['locomotor']['energy']=dict(load=self.carried_load(aid),climb_resistance=self.resistance(aid,action='climb'),samples=samples)
        if self.ground_appearance_enabled:
            from .ground_appearance import sample
            p['ground_appearance']=sample(self,aid,p)
        return p
