"""Opt-in finite measured-effort fatigue and recurrence-triggered rest.

State is part of the prospective decision, published only after observe admission.
No time passage alone is evidence of bodily rest; recovery needs a linked wait.
"""
from copy import deepcopy
from math import sqrt
from .exploration import fields, require
from .terrain_steering import SteeredResourceAgent, SteeredResourceExploration
from .movement_recurrence import diagnose_window
from .resource_exploration import PERIOD_US

SCHEMA = "l15a-movement-rest-v1"
MODES = ("disabled", "fatigue", "repetition", "combined")
REST_US = 1000000
REST_DECISIONS = 4
COOLDOWN_OBSERVATIONS = 8
MAX_RESTS_PER_PERIOD = 4


def advance_rest(previous, now, period, results, last_result, last_capture, linked, recurrence):
    """Pure bounded accounting over already validated body results."""
    s = deepcopy(previous) if previous else dict(fatigue=0., residual=0., charged=[], consumed=[],
        capture_us=now, period=period, starts=0, active=None, cooldown=0)
    elapsed = now-s["capture_us"]
    require(elapsed >= 0, "rest_time_order")
    if period != s["period"]:
        s.update(period=period, starts=0, active=None)
    effort = 0.
    for op, r in results.items():
        if op not in s["charged"]:
            effort += sqrt(r["forward"]**2+r["right"]**2+r.get("up",0)**2) + abs(r["yaw"])/360
            s["charged"].append(op)
    recovery = 0.
    if linked and last_result["status"] == "waited":
        # At most one normal observation interval; no recovery from HTTP silence.
        recovery = 2*min(250000, max(0, now-last_result["executed_us"]))/1000000
    s["fatigue"] = min(12., max(0., s["fatigue"]+effort-recovery))
    s["residual"] = max(0., s["residual"]-.01*elapsed/1000000)
    ops = recurrence["operations"]
    contribute = (len(recurrence["sources"])==9 and len(ops)==8 and recurrence["repetition_eligible"]
                  and not set(ops).intersection(s["consumed"]))
    if contribute:
        s["residual"] = min(4., s["residual"]+1)
        s["consumed"].extend(ops)
    s["capture_us"] = now
    s["cooldown"] = max(0, s["cooldown"]-1)
    return s, dict(effort=effort, recovery=recovery, contribution=contribute)


class RestResourceAgent(SteeredResourceAgent):
    rest_mode = None

    def _decision(self, p):
        d = super()._decision(p)
        last = next(reversed(self.decisions.values())) if self.decisions else None
        old = last.get("rest",{}).get("state") if last else None
        history = list(self.observations.values())[-8:]
        records = [dict(observation=o, command=self.commands[o["observation_id"]],
                        result=self.results.get("op:"+o["observation_id"])) for o in history]
        records.append(dict(observation=p, command=None, result=None))
        recurrence = diagnose_window(records, purpose_scoped=False)
        prev = history[-1] if history else None
        result = self.results.get("op:"+prev["observation_id"]) if prev else None
        linked = (result is not None and result["after_pose_ref"]==p["pose_ref"]
                  and result["after_revision"]==p["body_revision"] and result["executed_us"]<p["capture_us"])
        s, accounting = advance_rest(old, p["capture_us"], d["period"], self.results,
                                     result, prev["capture_us"] if prev else None, linked, recurrence)
        baseline = dict(action=list(d["action"]), reason=d["reason"])
        priority = (d["action"][0]=="pickup" or d["reason"].startswith("variation_")
                    or d["reason"] in ("body_correspondence_unavailable", "inventory_capacity", "acquisition_incomplete"))
        transition = "inactive"
        if s["active"] and (priority or p["capture_us"]>=s["active"]["until_us"] or s["active"]["decisions"]>=REST_DECISIONS):
            transition = "interrupted" if priority else "resumed"
            s["active"] = None
            s["cooldown"] = COOLDOWN_OBSERVATIONS
        reasons=[]
        if self.rest_mode in ("fatigue","combined") and s["fatigue"]>=4: reasons.append("fatigue")
        if self.rest_mode in ("repetition","combined") and s["residual"]>=2 and accounting["contribution"]:
            reasons.append("repetition")
        if (reasons and not priority and s["active"] is None and s["cooldown"]==0
                and s["starts"]<MAX_RESTS_PER_PERIOD and d["action"][0] in ("move","turn")):
            s["starts"]+=1
            s["active"]=dict(source=p["observation_id"], reasons=reasons, decisions=0,
                until_us=min(p["capture_us"]+REST_US,(d["period"]+1)*PERIOD_US))
            if "repetition" in reasons:s["residual"]-=2  # consume one request, not the historical evidence
            transition="started"
        if s["active"]:
            s["active"]["decisions"]+=1
            if transition!="started":transition="resting"
            d.update(action=["wait",0], target="", reason="finite_rest")
            # The fixed survey was interrupted, not successfully completed in place.
            if d["neighborhood"]["phase"]=="survey":
                d["neighborhood"].update(phase="incomplete",outcome="rest_interrupted")
                d["landmark"].update(stage="terminated",outcome="rest_interrupted")
        d["rest"]=dict(mode=self.rest_mode,state=s,accounting=accounting,recurrence=recurrence,
                       baseline=baseline,transition=transition,priority=priority)
        return d

    def snapshot(self):
        s=super().snapshot()
        s.update(movement_control=SCHEMA,rest_mode=self.rest_mode)
        return s


class RestResourceExploration(SteeredResourceExploration):
    schema=SCHEMA
    agent_type=RestResourceAgent

    def dispatch(self,name,value):
        if name!="configure":return super().dispatch(name,value)
        with self.lock:
            fields(value,"schema run_id world_epoch agent_id clock_id teaching selection_profile rest_mode")
            mode=value["rest_mode"]
            require(isinstance(mode,str) and mode in MODES,"rest_mode")
            require(value["agent_id"] in self.agents,"unknown_agent")
            a=self.agents[value["agent_id"]]
            require(a.rest_mode in (None,mode),"rest_configuration_conflict")
            response=super().dispatch(name,{k:deepcopy(v) for k,v in value.items() if k!="rest_mode"})
            a.rest_mode=mode
            return dict(response,rest_mode=mode)
