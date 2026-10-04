"""Opt-in body World with shared spatial resistance strips and unit-weight food."""
from math import floor
from .body_exploration import ExplorationBodyWorld,BodyAgent,BodyCampaign
from .world import segment_hit
from runtime.layered_body import capabilities
from runtime.energy_connection import ANGLES


class EnergyAgent(BodyAgent):
    energy_enabled=True


class EnergyCampaign(BodyCampaign):
    agent_type=EnergyAgent


class EnergyWorld(ExplorationBodyWorld):
    def carried_load(self,aid):
        return float(self.agents[aid]['inventory'])

    def resistance(self,aid,angle=0,action='walk'):
        a=self.agents[aid];dx,dz=self.direction(aid,angle)
        distance=capabilities(self.bodies[aid],self.carried_load(aid))[action+'_distance']
        # Fixed local material strips; no destination, agent ID or success labels.
        return 5. if floor((a['x']+dx*distance/2)/2)%2 else 1.

    def packet(self,aid,slot):
        p=super().packet(aid,slot);a=self.agents[aid];samples=[]
        distance=capabilities(self.bodies[aid],self.carried_load(aid))['walk_distance']
        for angle in ANGLES:
            dx,dz=self.direction(aid,angle)
            clear=not any(o['solid'] and segment_hit((a['x'],a['z']),
                (a['x']+dx*distance,a['z']+dz*distance),o,.2) for o in self.objects)
            samples.append(dict(angle=angle,clear=clear,resistance=self.resistance(aid,angle)))
        p['locomotor']['energy']=dict(load=self.carried_load(aid),climb_resistance=self.resistance(aid,action='climb'),samples=samples)
        return p
