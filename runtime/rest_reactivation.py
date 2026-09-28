"""Finite rest-time episodic retrieval and explicit cognitive-mode transitions.

An experimental information-routing policy, not a biological DMN model or new M_B.
"""
from copy import deepcopy
import json
from math import isclose
from .exploration import fields, require
from .movement_rest import RestResourceAgent, RestResourceExploration
from .movement_recurrence import view_key
from .harvest_predictability import affordance, section
from .terrain_resource_exploration import terrain_action

SCHEMA = "l15a-rest-reactivation-v1"
MAX_SCAN = 16
MAX_RECORDS = 3
MAX_AGE_US = 5000000
EPISODIC_PENALTY = .5


def appearance_key(packet):
    # view_key contains tuple pairs; persisted evidence must be JSON-native.
    return json.loads(json.dumps(view_key(packet),allow_nan=False))


def retrieve(records, current, model_ref):
    """Only this agent's already received records; newest three eligible results."""
    require(len(records)<=MAX_SCAN,"retrieval_budget")
    selected=[];seen=set()
    for record in reversed(records):
        p,c,r=record["observation"],record["command"],record["result"]
        require(all(p[k]==current[k] for k in ("run_id","agent_id","world_epoch","clock_id")),"retrieval_binding")
        require(p["capture_us"]<current["capture_us"],"retrieval_future")
        if r is None:continue
        require(c["source_id"]==p["observation_id"]==r["source_id"] and c["operation_id"]==r["operation_id"],"retrieval_source")
        require(all(r[k]==current[k] for k in ("run_id","agent_id","world_epoch")),"retrieval_result_binding")
        require(p["capture_us"]<=r["executed_us"]<current["capture_us"],"retrieval_result_future")
        require(r["operation_id"] not in seen,"retrieval_duplicate")
        seen.add(r["operation_id"])
        if (r["status"] not in ("blocked","moved","picked_up","not_found")
                or current["capture_us"]-p["capture_us"]>MAX_AGE_US):continue
        if len(selected)==MAX_RECORDS:continue
        selected.append(dict(source=p["observation_id"],operation_id=r["operation_id"],capture_us=p["capture_us"],
            pose_ref=p["pose_ref"],revision=p["body_revision"],after_pose_ref=r["after_pose_ref"],
            after_revision=r["after_revision"],kind=c["kind"],result_status=r["status"],
            acquired=r["acquired"],observed=appearance_key(p),authority="episodic; not adopted relation"))
    return dict(source=current["observation_id"],capture_us=current["capture_us"],model_ref=model_ref,
        binding={k:current[k] for k in ("run_id","agent_id","world_epoch","clock_id")},
        scanned=len(records),records=selected)


def evaluate(bundle, current, model, invalidated=False):
    require(bundle["binding"]=={k:current[k] for k in bundle["binding"]},"reactivation_binding")
    require(current["capture_us"]>=bundle["capture_us"],"reactivation_time")
    current_ref=model.model_ref if model else None
    model_changed=current_ref!=bundle["model_ref"]
    model_result=dict(status="no_adopted_model",model_ref=current_ref)
    if model_changed:model_result["status"]="model_changed"
    elif invalidated:model_result["status"]="model_invalidated"
    elif model:
        require(model.agent_id==current["agent_id"],"reactivation_model_agent")
        model_result=model.interpret_harvest_pattern(section(current["run_id"],current["agent_id"],
            "before",False,affordance(current)))
    observations=appearance_key(current);out=[]
    for r in bundle["records"]:
        reasons=[]
        if current["capture_us"]-r["capture_us"]>MAX_AGE_US:reasons.append("expired")
        if model_changed:reasons.append("model_changed")
        if observations is None or r["observed"] is None:reasons.append("observation_incomplete")
        elif observations!=r["observed"]:reasons.append("observed_context_changed")
        if not (r["pose_ref"]==r["after_pose_ref"]==current["pose_ref"] and
                r["revision"]==r["after_revision"]==current["body_revision"]):
            reasons.append("pose_correspondence_unavailable")
        eligible=not reasons and r["kind"]=="move" and r["result_status"]=="blocked"
        out.append(dict(source=r["source"],operation_id=r["operation_id"],reasons=reasons,
            kind=r["kind"],result_status=r["result_status"],acquired=r["acquired"],applicable=eligible))
    # One temporary cost, never multiple independent votes or a permanent wall.
    return dict(records=out,model=model_result,forward_penalty=EPISODIC_PENALTY if any(r["applicable"] for r in out) else 0.)


def project_reactivation(terrain, action, evaluation):
    out=dict(baseline_action=list(action),selected_action=list(action),applied=False,changed=False,contributions=[])
    if not terrain or terrain["status"]!="complete" or action[0] not in ("move","turn"):
        out["reason"]="current_priority_or_geometry";return out
    penalty=evaluation["forward_penalty"]
    if not penalty:out["reason"]="no_applicable_directional_record";return out
    adjusted=deepcopy(terrain)
    for row in adjusted["directional_samples"]:
        if row["direction_deg"]==0 and row["status"]=="scored":
            row["total"]+=penalty
            out["contributions"].append(dict(direction_deg=0,value=penalty,
                operations=[r["operation_id"] for r in evaluation["records"] if r["applicable"]]))
    if not out["contributions"]:out["reason"]="direction_not_scored";return out
    scored=[r for r in adjusted["directional_samples"] if r["status"]=="scored"]
    minimum=min(r["total"] for r in scored)
    adjusted["minimum_height"]=minimum
    adjusted["minimum_directions"]=[r["direction_deg"] for r in scored if isclose(r["total"],minimum,abs_tol=1e-9)]
    choice,_=terrain_action(adjusted)
    out.update(selected_action=choice,applied=True,changed=choice!=action,reason="temporary_episodic_cost")
    return out


class ReactivatingAgent(RestResourceAgent):
    reactivation_mode=None

    def _decision(self,p):
        d=super()._decision(p)
        rest=d["rest"]
        last=next(reversed(self.decisions.values())) if self.decisions else None
        previous=last.get("reactivation") if last else None
        phase="external_observation";bundle=None;evaluation=None;projection=None
        enabled=self.reactivation_mode=="enabled"
        # The prospective model is frozen for this observation by the existing admission path.
        learning,model=self._prospective
        if enabled and rest["state"]["active"]:
            phase="internal_reactivation"
            if rest["transition"]=="started":
                history=list(self.observations.values())[-MAX_SCAN:]
                records=[dict(observation=o,command=self.commands[o["observation_id"]],
                    result=self.results.get("op:"+o["observation_id"])) for o in history]
                bundle=retrieve(records,p,model.model_ref if model else None)
            elif previous:bundle=deepcopy(previous["bundle"])
        elif enabled and rest["transition"]=="resumed" and previous and previous["bundle"]:
            phase="resume_review";bundle=deepcopy(previous["bundle"])
        if bundle:
            evaluation=evaluate(bundle,p,model,learning["invalidated"])
            if phase=="resume_review":
                projection=project_reactivation(d["movement_terrain"],d["action"],evaluation)
                if not rest["priority"] and projection["changed"]:
                    d.update(action=projection["selected_action"],target="",reason="rest_reactivation")
        d["reactivation"]=dict(mode=self.reactivation_mode,phase=phase,
            previous_phase=previous["phase"] if previous else None,
            trigger=rest["transition"],body_resting=rest["state"]["active"] is not None,
            observation_source=p["observation_id"],bundle=bundle,evaluation=evaluation,projection=projection)
        return d

    def snapshot(self):
        s=super().snapshot();s.update(movement_control=SCHEMA,reactivation_mode=self.reactivation_mode);return s


class ReactivatingExploration(RestResourceExploration):
    schema=SCHEMA
    agent_type=ReactivatingAgent

    def dispatch(self,name,value):
        if name!="configure":return super().dispatch(name,value)
        with self.lock:
            fields(value,"schema run_id world_epoch agent_id clock_id teaching selection_profile rest_mode reactivation_mode")
            mode=value["reactivation_mode"]
            require(isinstance(mode,str) and mode in ("disabled","enabled"),"reactivation_mode")
            require(value["agent_id"] in self.agents,"unknown_agent")
            a=self.agents[value["agent_id"]]
            require(a.reactivation_mode in (None,mode),"reactivation_configuration_conflict")
            response=super().dispatch(name,{k:deepcopy(v) for k,v in value.items() if k!="reactivation_mode"})
            a.reactivation_mode=mode
            return dict(response,reactivation_mode=mode)
