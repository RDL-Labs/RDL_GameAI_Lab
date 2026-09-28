"""Explicit local appraisal of an adopted relation, not distant harvest prediction.

The field proposes an approach-to-test opportunity. It never extends the source
model's prediction domain or writes model/Experience/terrain input state.
"""
from copy import deepcopy
from math import fsum, isclose
from .exploration import require
from .learned_exploration import observation_key
from .harvest_predictability import RELATION, PURPOSE, affordance, section

RULE = "l15a-adopted-harvest-approach-field-v1"
GAIN = .5


def project(terrain, packet, model, learning, mode):
    require(mode in ("disabled", "enabled"), "model_field_mode")
    require(all(terrain["context"][k]==packet[k] for k in terrain["context"]), "model_field_observation_binding")
    out=deepcopy(terrain)
    trace=dict(rule=RULE, mode=mode, model_ref=model.model_ref if model else None,
        source_observation=packet["observation_id"], source_candidate=None,
        purpose="approach-to-test-observed-matching-appearance",
        prediction=None, status="no_adopted_model", applied=False, contributions=[],
        formation=[], validation=[], gain=GAIN)
    out["model_field"]=trace
    if model is None: return out
    require(model.agent_id==packet["agent_id"], "model_field_agent")
    if learning["invalidated"]:
        trace["status"]="model_invalidated";return out
    admission=learning["admission"]
    require(admission and admission["status"]=="ADOPTED", "model_field_admission")
    candidate=admission["candidate"]
    matches=[r for r in model.adopted_relations if r["source_candidate_id"]==candidate["candidate_id"]
        and r["relation"].get("kind")==RELATION]
    require(len(matches)==1, "model_field_candidate_binding")
    relation=matches[0]["relation"]
    require(relation==candidate["common_relation_signature"], "model_field_relation_binding")
    require(relation["run_id"]==packet["run_id"] and relation["purpose"]==PURPOSE,
        "model_field_context")
    require(candidate["agent_id"]==packet["agent_id"], "model_field_candidate_agent")
    records=admission["records"]
    require(len(records)==5 and [r["operation_id"] for r in records]==relation["formation"]+relation["validation"],
        "model_field_sources")
    require(all(r["agent_id"]==packet["agent_id"] and r["later_us"]<=packet["capture_us"] for r in records),
        "model_field_source_time")
    trace.update(source_candidate=candidate["candidate_id"], formation=list(relation["formation"]),
        validation=list(relation["validation"]))
    frame=packet["distant"]
    if relation["profile"] != [frame["profile_id"],frame["profile_revision"]]:
        trace["status"]="profile_mismatch";return out
    # Preserve the exact existing prediction domain: only currently reachable
    # affordances can produce a known harvest forecast.
    trace["prediction"]=model.interpret_harvest_pattern(section(packet["run_id"],packet["agent_id"],
        "before",False,affordance(packet)))
    if observation_key(packet) is None:
        trace["status"]="observation_incomplete";return out
    if out["status"]!="complete":
        trace["status"]="geometry_incomplete";return out
    refs={i["ref"] for i in packet["food"]["visible"] if i["appearance"]==relation["appearance"]}
    for row in out["directional_samples"]:
        if row["status"]!="scored": continue
        sources=[x for x in row["source_contributions"]["food"] if x["ref"] in refs]
        if not sources: continue
        # Each source's normalized proximity is in [-4, 0]. Fixed local
        # appraisal gain, not learned reward, probability, or Core E/H.
        cost=max(-GAIN,min(0.,fsum(x["normalized"] for x in sources)*GAIN/4.))
        trace["contributions"].append(dict(direction_deg=row["direction_deg"], value=cost,
            target_refs=[x["ref"] for x in sources]))
        if mode=="enabled":
            row["model_field_cost"]=cost
            row["total"]=fsum((row["total"],cost))
    if not trace["contributions"]:
        trace["status"]="no_current_matching_target";return out
    trace.update(status="applied" if mode=="enabled" else "disabled_counterfactual", applied=mode=="enabled")
    if trace["applied"]:
        scored=[r for r in out["directional_samples"] if r["status"]=="scored"]
        out["minimum_height"]=min(r["total"] for r in scored)
        out["minimum_directions"]=[r["direction_deg"] for r in scored
            if isclose(r["total"],out["minimum_height"],rel_tol=0,abs_tol=1e-9)]
    return out
