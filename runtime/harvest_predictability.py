"""L14B finite induction and explicit T1 admission of a harvesting pattern.

Three formation operations and two later, unused validation operations. They
are NOT five independent resource sites. No stock quantity enters this module.
"""
from copy import deepcopy
import json

from .exploration import fields, require
from .exploration_series import digest
from .learned_exploration import observation_key, projection
from .v23_interpretation import GameAIFrozenComparisonSidecar

RELATION = "l14b-harvest-affordance-persistence-v1"
PURPOSE = "predict-one-harvest-and-subsequent-observed-affordance"
PROFILES = {
    "steady": dict(desired_variation=0, sensitivity=0, threshold=6),
    "curious": dict(desired_variation=1, sensitivity=1, threshold=6),
    "restless": dict(desired_variation=1, sensitivity=2, threshold=6),
}


def affordance(p):
    if observation_key(p) is None:
        return None
    return any(f["appearance"] == "brown_capped_ovoid" and f["distance"] <= 1.25
               for f in p["food"]["visible"])


def tendency(profile, confirmations):
    """Local variation demand. Not Core H/theta, and never a prediction error."""
    require(profile in PROFILES, "selection_profile")
    require(type(confirmations) is int and confirmations >= 0, "confirmations")
    t = PROFILES[profile]
    difference = t["desired_variation"] if confirmations else 0
    load = confirmations * difference * t["sensitivity"]
    return dict(profile=profile, stimulation_difference=difference, load=load,
                threshold=t["threshold"], request_exploration=load >= t["threshold"])


def interpret(model, section):
    fields(section, "run_id agent_id purpose complete stage acquired affordance")
    require(section["agent_id"] == model.agent_id and section["purpose"] == PURPOSE, "harvest_boundary")
    require(type(section["complete"]) is bool and section["stage"] in ("before", "after"), "harvest_section")
    require(type(section["affordance"]) is bool and type(section["acquired"]) is bool, "harvest_values")
    matches = [r for r in model.adopted_relations if r["relation"].get("kind") == RELATION
               and r["relation"]["run_id"] == section["run_id"]]
    result = dict(model_ref=model.model_ref, status="unknown", values=None)
    if not section["complete"] or len(matches) != 1:
        return result
    if section["stage"] == "before" and not section["affordance"]:
        return result
    values = dict(acquired=1, affordance_persists=1) if section["stage"] == "before" else dict(
        acquired=int(section["acquired"]), affordance_persists=int(section["affordance"]))
    return dict(result, status="known", values=values, source_candidate=matches[0]["source_candidate_id"])


def section(run, agent, stage, acquired, present):
    return dict(run_id=run, agent_id=agent, purpose=PURPOSE, complete=present is not None,
                stage=stage, acquired=acquired, affordance=present is True)


def build_admission(run, agent, records, observations):
    """Construct off to the side, publish only with a successful observation.

The explicit inspector reviews a real observed-count difference, independently
of the harvesting validation. Boredom never manufactures a canonical rupture.
"""
    require(len(records) >= 5, "five_operations_required")
    selected = records[:5]
    require(len({r["operation_id"] for r in selected}) == 5, "distinct_operations_required")
    require(all(r["agent_id"] == agent for r in selected), "experience_agent")
    if not all(r["acquired"] and r["affordance_persists"] for r in selected):
        return None, dict(status="REJECT", reason="held_out_or_formation_counterexample", records=deepcopy(selected))
    ps = [p for p in observations if observation_key(p) is not None]
    if not ps:
        return None, dict(status="DEFER", reason="count_section_unavailable")
    first = ps[0]
    later = next((p for p in ps[1:] if len(p["food"]["visible"]) != len(first["food"]["visible"])), None)
    if later is None:
        return None, dict(status="DEFER", reason="actual_count_difference_unavailable")
    canonical = GameAIFrozenComparisonSidecar()
    for p in (first, later):
        packet = projection(p, run, 1)
        packet["observation"]["perception_rule"] = "l14b-observed-material-count:"+run
        canonical.capture(packet)
    path = canonical.snapshot()["review_path"]["paths"][0]
    review = canonical.review_assessment(dict(assessment_id=path["assessment_id"], expected_revision=0,
        reviewer="l14b-explicit-finite-inspector", basis="actual material-count Difference; not stimulation demand",
        evidence=later["observation_id"], dimensions={k:dict(status="unresolved", residual=abs(v)) if v else
            dict(status="zero") for k,v in path["E"]["deltas"].items()}))
    relation = dict(kind=RELATION, run_id=run, purpose=PURPOSE, appearance="brown_capped_ovoid",
        profile=["fixture-distant-enabled", 1], prediction=dict(acquired=1, affordance_persists=1),
        formation=[r["operation_id"] for r in selected[:3]], validation=[r["operation_id"] for r in selected[3:]],
        scope="five distinct operations; sites may coincide; no stock or universal tree claim")
    candidate = dict(candidate_id="l14b-candidate:"+digest([agent, relation])[:24], agent_id=agent,
        support_count=3, validation_count=2, common_relation_signature=relation)
    experiences = [dict(record_id=r["operation_id"], **deepcopy(r)) for r in selected]
    bundle = canonical.expand_t1_materials(assessment_id=review["assessment_id"], candidates=[candidate], experiences=experiences)
    require(bundle is not None, "T1_capacity")
    decisions = [dict(material_id=m["material_id"], disposition="RETAIN" if m["kind"] in
        ("current_M_B", "CandidateRelation") else "DEFER", basis="three formation and two unused validation operations",
        evidence=digest(selected)) for m in bundle["materials"]]
    selection = canonical.inspect_t1_materials(bundle_id=bundle["bundle_id"], payload=dict(expected_revision=0,
        reviewer="l14b-explicit-finite-inspector", materials=decisions))
    artifact = canonical.reconstruct_t1(bundle_id=bundle["bundle_id"])
    require(selection is not None and artifact is not None, "T1_capacity")
    cutover = canonical.cutover_reentry(artifact_id=artifact["artifact_id"], expected_active_model_ref=artifact["parent_model_ref"],
        operator="l14b-between-operations-checkpoint", basis="activate inspected finite harvest prediction", evidence=digest(selected))
    require(cutover is not None, "cutover_capacity")
    return canonical.model_for_agent(agent), dict(status="ADOPTED", candidate=candidate, records=deepcopy(selected),
        canonical=json.loads(json.dumps(canonical.snapshot())), cutover=cutover)
