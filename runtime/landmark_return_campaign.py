"""Thirty-day opt-in; identical day policy, externally audited return-trip stop."""
from copy import copy, deepcopy
from .landmark_day_cycle import DayCycleAgent, DAY_US
from .terrain_steering import SteeredResourceExploration
from .exploration import require

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

    def _decision(self, packet):
        decision=super()._decision(packet)
        if self.mb_field_mode != "off":
            terrain=decision["movement_terrain"]
            trace=terrain.get("model_field") if terrain else None
            decision["mb_field"]=dict(mode=self.mb_field_mode, field=trace,
                gate=decision["terrain_gate"], final_action=list(decision["action"]),
                final_reason=decision["reason"])
        return decision

    def _stage_sensory_store(self):
        return admission_fork(self.store)


class ReturnCampaign(SteeredResourceExploration):
    schema=SCHEMA
    agent_type=CampaignAgent

    def __init__(self,run_id,periods=30,seed=20260928,assignment="steady", mb_field_mode="off"):
        require(type(periods) is int and 1<=periods<=30,"campaign_day_budget")
        require(mb_field_mode in ("off","disabled","enabled"),"model_field_mode")
        super().__init__(run_id,periods,seed,assignment)
        self.mb_field_mode=mb_field_mode
        for agent in self.agents.values(): agent.mb_field_mode=mb_field_mode

    def dispatch(self,name,value):
        if name=="configure":
            require(value.get("mb_field_mode","off")==self.mb_field_mode,"model_field_configuration")
            value={k:v for k,v in value.items() if k!="mb_field_mode"}
        return super().dispatch(name,value)

    def snapshot(self):
        s=super().snapshot();s["period_us"]=DAY_US
        if self.mb_field_mode!="off": s["mb_field_mode"]=self.mb_field_mode
        return s
