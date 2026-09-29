"""Thirty-day opt-in; identical day policy, externally audited return-trip stop."""
from copy import copy, deepcopy
from .landmark_day_cycle import DayCycleAgent, DAY_US
from .terrain_steering import SteeredResourceExploration
from .exploration import require
from .current_harvest_state import assess

SCHEMA="l15a-landmark-return-campaign-v1"


def admission_fork(store):
    """Only admit/record_rejection may mutate the fork; old frames are immutable.

    Public snapshots remain deep copies. Never use this as a general deepcopy.
    SensoryObservationStore.admit validates first and only appends new frames.
    """
    result=copy(store)
    result.assignments=dict(store.assignments)
    result._frames={k:list(v) for k,v in store._frames.items()}
    result._by_id=dict(store._by_id)
    result._latest_order=dict(store._latest_order)
    result._rejections=deepcopy(store._rejections)
    return result


class CampaignAgent(DayCycleAgent):
    allow_return_target=True
    harvest_state=False
    allowed_agent_ids=tuple("npc_"+c for c in "abcdef")

    def _stage_day_state(self, old):
        # Completed night entries and initial home evidence are never edited.
        # Copy the list for a possible append, and all mutable current state.
        state=deepcopy({k:v for k,v in old.items() if k not in ("nights","home_memory")})
        state["nights"]=list(old["nights"])
        state["home_memory"]=old["home_memory"]
        return state

    def _store_decision(self, decision):
        stored=deepcopy({k:v for k,v in decision.items() if k!="day_cycle"})
        stored["day_cycle"]=self._stage_day_state(decision["day_cycle"])
        return stored

    def _snapshot_decisions(self):
        # Expand shared history at the public boundary. Separate deepcopy memos
        # preserve independence between caller-visible decision records too.
        return {key:deepcopy(value) for key,value in self.decisions.items()}

    def _decision(self, packet):
        decision=super()._decision(packet)
        if self.mb_field_mode != "off":
            terrain=decision["movement_terrain"]
            trace=terrain.get("model_field") if terrain else None
            decision["mb_field"]=dict(mode=self.mb_field_mode, field=trace,
                gate=decision["terrain_gate"], final_action=list(decision["action"]),
                final_reason=decision["reason"])
        if self.harvest_state:
            decision["current_harvest"]=assess(packet,self.teaching["appearance"],self._prospective[0]["records"])
        return decision

    def _stage_sensory_store(self):
        return admission_fork(self.store)


class ReturnCampaign(SteeredResourceExploration):
    schema=SCHEMA
    agent_type=CampaignAgent

    def __init__(self,run_id,periods=30,seed=20260928,assignment="steady", mb_field_mode="off", harvest_state=False, agent_count=3):
        require(type(periods) is int and 1<=periods<=30,"campaign_day_budget")
        require(mb_field_mode in ("off","disabled","enabled"),"model_field_mode")
        require(type(agent_count) is int and agent_count in (3,6),"campaign_agent_count")
        require(agent_count==3 or assignment=="steady","six_agent_steady_assignment")
        self.agent_count=agent_count
        self.agent_ids=CampaignAgent.allowed_agent_ids[:agent_count]
        super().__init__(run_id,periods,seed,assignment)
        require(type(harvest_state) is bool,"harvest_state_mode")
        self.harvest_state=harvest_state
        self.mb_field_mode=mb_field_mode
        for agent in self.agents.values():
            agent.mb_field_mode=mb_field_mode
            agent.harvest_state=harvest_state

    def dispatch(self,name,value):
        if name=="configure":
            require(value.get("agent_count",3)==self.agent_count,"campaign_population_binding")
            value={k:v for k,v in value.items() if k!="agent_count"}
            require(value.get("mb_field_mode","off")==self.mb_field_mode,"model_field_configuration")
            value={k:v for k,v in value.items() if k!="mb_field_mode"}
        return super().dispatch(name,value)

    def snapshot(self):
        s=super().snapshot();s["period_us"]=DAY_US
        if self.mb_field_mode!="off": s["mb_field_mode"]=self.mb_field_mode
        if self.harvest_state: s["harvest_state"]=True
        if self.agent_count!=3: s["agent_count"]=self.agent_count
        return s
