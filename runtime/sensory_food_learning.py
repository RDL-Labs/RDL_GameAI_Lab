"""L10: an explicit, finite sensory relation -> M_B -> action experiment.

The shared frozen M_B owns interpretation. This adapter owns acquisition,
inductive material formation, fixed inspection, and a separately opted-in
action rule. It never infers World identity from a sensory feature.
"""

from copy import deepcopy
import hashlib
import json

from .v23_interpretation import GameAIInterpretation, compare_interpretations

PURPOSE = "predict-bounded-food-attempt-from-distant-color"
RELATION = "sensory-food-table-v1"
CONTEXT = "l10-fixed-food-apparatus-v1"
SHARED_CONTEXT = "l10c-shared-food-apparatus-v1"
CONTEXTS = (CONTEXT, SHARED_CONTEXT)
MAX_OPERATIONS = 16


def identity(prefix, value):
    return prefix + hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()[:24]


def text_id(value, name):
    if not isinstance(value, str) or not value.strip() or len(value) > 128:
        raise ValueError(name + " must be nonempty and at most 128 characters")
    return value


def acquire(snapshot, request, *, context=CONTEXT):
    """Select one complete frontal coarse feature, never a World lookup."""
    if context not in CONTEXTS:
        raise ValueError("unsupported apparatus context")
    if type(request["world_epoch"]) is not int or request["run_id"] != snapshot["run_id"] or request["world_epoch"] != snapshot["world_epoch"]:
        raise ValueError("run/epoch mismatch")
    frame = next((f for f in snapshot["frames"] if f["frame_id"] == request["frame_id"]), None)
    if frame is None or frame["agent_id"] != request["agent_id"]:
        raise ValueError("unknown or foreign frame")
    now = request["now_us"]
    if type(now) is not int or now < frame["capture_window"]["end_us"]:
        raise ValueError("invalid current acquisition clock")
    reasons = []
    if frame["channel"] != "vision_distant" or frame["sensor_model_revision"] != "sampled-surface-v0.2":
        reasons.append("unsupported_sensor")
    if frame["profile_id"] not in ("fixture-life-sensory", "fixture-life-sensory-compact"):
        reasons.append("unsupported_profile")
    if frame["clock_id"] != "world-sim-v1" or frame["profile_revision"] != 1:
        reasons.append("unsupported_conditions")
    if frame["status"] != "SAMPLED" or frame["coverage"] != "COMPLETE_WITHIN_PLAN" or frame["output_limited"]:
        reasons.append("acquisition_incomplete")
    if now - frame["capture_window"]["end_us"] > 500000:
        reasons.append("stale_source")
    features = frame["payload"].get("features", [])
    if len(features) != 1:
        reasons.append("single_feature_unavailable")
    elif not (-5 <= features[0]["azimuth_interval_deg"][0] < features[0]["azimuth_interval_deg"][1] <= 5):
        reasons.append("outside_selected_sector")
    elif features[0]["color_band"] == "unknown":
        reasons.append("appearance_unknown")
    return {
        "purpose": PURPOSE, "context": context, "run_id": request["run_id"],
        "world_epoch": request["world_epoch"], "agent_id": request["agent_id"],
        "section_id": identity("l10-section:", [frame["frame_id"], PURPOSE]),
        "frame_id": frame["frame_id"], "capture_window": deepcopy(frame["capture_window"]),
        "observer_frame_ref": frame["observer_frame_ref"], "clock_id": frame["clock_id"],
        "profile_id": frame["profile_id"], "profile_revision": frame["profile_revision"],
        "sensor_model_revision": frame["sensor_model_revision"],
        "sampled_world_tick": frame["sampled_world_tick"],
        "feature": deepcopy(features[0]) if len(features) == 1 else None,
        "reasons": reasons, "phase": "before", "outcome": None,
    }


def relation_context(section):
    return {key: section[key] for key in (
        "purpose", "context", "run_id", "world_epoch", "agent_id", "profile_id",
        "profile_revision", "sensor_model_revision", "clock_id")}


def interpret(model, section):
    """Executable, purpose-scoped part of a frozen M_B, including unknown."""
    if section["agent_id"] != model.agent_id or section["purpose"] != PURPOSE or section["context"] not in CONTEXTS:
        raise ValueError("sensory interpretation boundary mismatch")
    result = {"model_ref": model.model_ref, "section_id": section["section_id"],
              "tick": section["sampled_world_tick"],
              "boundary": relation_context(section), "status": "unknown", "values": None,
              "source_candidates": [], "reasons": deepcopy(section["reasons"])}
    if result["reasons"]:
        return result
    if section["phase"] == "after":
        if type(section["outcome"]) is not bool:
            raise ValueError("post-action section requires an observed outcome")
        value = section["outcome"]
    else:
        matches = [r for r in model.adopted_relations
                   if r["relation"].get("kind") == RELATION
                   and r["relation"].get("boundary") == relation_context(section)
                   and r["relation"].get("color_band") == section["feature"]["color_band"]]
        if not matches:
            result["reasons"] = ["unlearned_condition"]
            return result
        values = {r["relation"].get("predicts_acquired") for r in matches}
        if len(values) != 1 or any(type(r["relation"].get("predicts_acquired")) is not bool for r in matches):
            raise ValueError("ambiguous or malformed executable relation")
        value = values.pop()
        result["source_candidates"] = [r["source_candidate_id"] for r in matches]
    result.update(status="known", values={"food_acquired": float(value)})
    return result


def comparison(before, after):
    if before["status"] != "known" or after["status"] != "known":
        return {"status": "not_comparable", "E": None, "reason": "unknown_interpretation"}
    def convert(value):
        return GameAIInterpretation(
            section_id=value["section_id"], source_observation_id=value["section_id"], tick=value["tick"],
            agent_id=value["boundary"]["agent_id"],
            context_key=(json.dumps(value["boundary"], sort_keys=True),),
            model_ref=value["model_ref"], values=value["values"],
            provenance={"formation": "interp(frozen-M_B,sensory-food-section)"})
    return {"status": "compared", "E": compare_interpretations(convert(before), convert(after)).to_json()}


class SensoryFoodLearning:
    """One bounded agent episode ledger; HTTP caller serializes mutations."""

    def __init__(self, sensory, canonical, *, agent_id=None, context=CONTEXT):
        if context not in CONTEXTS:
            raise ValueError("unsupported apparatus context")
        self._context = context
        self.sensory = sensory
        self.canonical = canonical
        self.agent_id = agent_id
        self._operations = {}
        self._results = {}
        self._models = {}
        self._learning = {}

    def decide(self, request):
        required = {"operation_id", "episode_id", "run_id", "world_epoch", "agent_id", "frame_id", "now_us"}
        if set(request) != required:
            raise ValueError("decision requires exactly the declared finite input fields")
        for key in required - {"now_us", "world_epoch"}:
            text_id(request[key], key)
        self._check_agent(request)
        op = request["operation_id"]
        if op in self._operations:
            old = self._operations[op]
            if old["request"] != request:
                raise ValueError("operation replay conflict")
            return deepcopy(old["decision"])
        if len(self._operations) >= MAX_OPERATIONS:
            raise ValueError("operation capacity")
        if any(o["request"]["episode_id"] == request["episode_id"] for o in self._operations.values()):
            raise ValueError("episode already has a decision")
        if any(o["request"]["frame_id"] == request["frame_id"] for o in self._operations.values()):
            raise ValueError("source frame already used by a trial")
        section = acquire(self.sensory.snapshot(), request, context=self._context)
        model = self.canonical.model_for_agent(request["agent_id"])
        prediction = model.interpret_sensory_food(section)
        if section["reasons"]:
            action, basis = "defer", "acquisition_conditions_unavailable"
        elif prediction["status"] == "unknown":
            action, basis = "attempt_food", "bounded_exploration_of_unlearned_condition"
        elif prediction["values"]["food_acquired"] == 0:
            action, basis = "defer", "M_B_predicts_nonacquisition"
        else:
            action, basis = "attempt_food", "M_B_predicts_acquisition"
        decision = {"operation_id": op, "episode_id": request["episode_id"],
                    "agent_id": request["agent_id"], "frame_id": section["frame_id"],
                    "model_ref": model.model_ref, "prediction": prediction,
                    "action": action, "basis": basis,
                    "expires_us": section["capture_window"]["end_us"] + 1000000,
                    "authority": "one bounded Food attempt or defer; no repeated action authority"}
        if self.agent_id is not None:
            decision["decision_id"] = identity("l10b-decision:", [request, decision])
        self._operations[op] = {"request": deepcopy(request), "section": section, "decision": decision}
        self._models[op] = model
        return deepcopy(decision)

    def record(self, request):
        required = {"operation_id", "event_id", "completed_us", "attempted", "food_acquired"}
        if self.agent_id is not None:
            required |= {"agent_id", "decision_id"}
        if set(request) != required:
            raise ValueError("result requires exactly the declared factual fields")
        self._check_agent(request)
        op = request["operation_id"]
        text_id(request["event_id"], "event_id")
        if op not in self._operations:
            raise ValueError("unknown operation")
        if self.agent_id is not None and request["decision_id"] != self._operations[op]["decision"]["decision_id"]:
            raise ValueError("foreign or changed decision identity")
        if op in self._results:
            if self._results[op]["result"] != request:
                raise ValueError("result replay conflict")
            return deepcopy(self._results[op])
        if any(r["result"]["event_id"] == request["event_id"] for r in self._results.values()):
            raise ValueError("event reused by another operation")
        operation = self._operations[op]
        expected = operation["decision"]["action"] == "attempt_food"
        if type(request["attempted"]) is not bool or request["attempted"] != expected:
            raise ValueError("result does not match admitted action")
        if (expected and type(request["food_acquired"]) is not bool) or (not expected and request["food_acquired"] is not None):
            raise ValueError("unattempted is not a failure")
        start = operation["request"]["now_us"]
        if type(request["completed_us"]) is not int or not start <= request["completed_us"] <= start + 5000000:
            raise ValueError("result time outside operation boundary")
        section = deepcopy(operation["section"])
        scope = [self.agent_id] if self.agent_id is not None else []
        section.update(phase="after", outcome=request["food_acquired"],
                       section_id=identity("l10-result-section:", scope + [op, request["event_id"]]),
                       sampled_world_tick=request["completed_us"] // 250000)
        model = self._models[op]  # never reinterpret this outcome under a later active model
        after = model.interpret_sensory_food(section) if expected else None
        experience = None if not expected else {
            "record_id": identity("l10-experience:", scope + [operation["request"]["run_id"], request["event_id"]]),
            "agent_id": operation["request"]["agent_id"], "episode_id": operation["request"]["episode_id"],
            "event_id": request["event_id"], "operation_id": op,
            "section": deepcopy(operation["section"]), "food_acquired": request["food_acquired"],
            "source_model_ref": model.model_ref,
        }
        value = {"result": deepcopy(request), "experience": experience, "F_prime": after,
                 "comparison": comparison(operation["decision"]["prediction"], after) if expected else
                 {"status": "not_attempted", "E": None},
                 "authority": "direct-participant local Experience; E is not automatically H"}
        self._results[op] = value
        return deepcopy(value)

    def learn(self, request):
        if set(request) != {"learning_id", "agent_id", "formation_operations", "validation_operations", "assessment_id", "activate"}:
            raise ValueError("learning requires explicit sources, review and activation choice")
        self._check_agent(request)
        learning_id = text_id(request["learning_id"], "learning_id")
        if learning_id in self._learning:
            old = self._learning[learning_id]
            if old["request"] != request:
                raise ValueError("learning replay conflict")
            return deepcopy(old["response"])
        if self._learning:
            raise ValueError("L10 permits one reconstruction per run")
        if type(request["activate"]) is not bool:
            raise ValueError("activate must be explicit boolean")
        formation, validation = request["formation_operations"], request["validation_operations"]
        if not isinstance(formation, list) or not isinstance(validation, list) or len(formation) != 6 or len(validation) != 2:
            raise ValueError("L10 requires six formation and two held-out validation Experiences")
        ids = formation + validation
        if len(set(ids)) != len(ids):
            raise ValueError("formation and validation must be distinct")
        experiences = []
        for op in ids:
            experience = self._results.get(op, {}).get("experience")
            if experience is None or experience["agent_id"] != request["agent_id"]:
                raise ValueError("missing, unattempted or foreign Experience")
            if experience["section"]["reasons"]:
                raise ValueError("incomplete source acquisition")
            experiences.append(deepcopy(experience))
        context = relation_context(experiences[0]["section"])
        if any(relation_context(e["section"]) != context for e in experiences):
            raise ValueError("Experience conditions differ")
        colors = sorted({e["section"]["feature"]["color_band"] for e in experiences[:6]})
        if len(colors) != 2:
            raise ValueError("two observed color conditions required")
        candidates, inspections = [], []
        for color in colors:
            group = [e for e in experiences[:6] if e["section"]["feature"]["color_band"] == color]
            held = [e for e in experiences[6:] if e["section"]["feature"]["color_band"] == color]
            if len(group) != 3 or len(held) != 1:
                raise ValueError("each condition requires three formation and one independent validation")
            outcomes = {e["food_acquired"] for e in group}
            disposition = "DEFER" if len(outcomes) != 1 else (
                "RETAIN" if held[0]["food_acquired"] in outcomes else "REJECT")
            inspections.append({"color_band": color, "disposition": disposition,
                                "formation_experiences": [e["record_id"] for e in group],
                                "validation_experiences": [e["record_id"] for e in held]})
            if len(outcomes) != 1:
                continue
            signature = {"kind": RELATION, "boundary": context, "color_band": color,
                         "predicts_acquired": group[0]["food_acquired"],
                         "formation_experiences": [e["record_id"] for e in group],
                         "validation_experiences": [e["record_id"] for e in held]}
            candidates.append({"candidate_id": identity("l10-candidate:", signature),
                               "agent_id": request["agent_id"], "support_count": 3,
                               "common_relation_signature": signature})
        selected = {i["color_band"]: i["disposition"] for i in inspections}
        if not any(d == "RETAIN" for d in selected.values()):
            response = {"status": "no_retained_relation", "inspections": inspections}
        else:
            bundle = self.canonical.expand_t1_materials(assessment_id=request["assessment_id"],
                                                        candidates=candidates, experiences=experiences)
            if bundle is None:
                raise ValueError("T1 material capacity")
            decisions = []
            for material in bundle["materials"]:
                disposition = "RETAIN" if material["kind"] == "current_M_B" else "DEFER"
                if material["kind"] == "CandidateRelation":
                    disposition = selected[material["payload"]["common_relation_signature"]["color_band"]]
                decisions.append({"material_id": material["material_id"], "disposition": disposition,
                                  "basis": "L10 unanimity in three formation and agreement in held-out Experience",
                                  "evidence": learning_id})
            selection = self.canonical.inspect_t1_materials(bundle_id=bundle["bundle_id"], payload={
                "expected_revision": 0, "reviewer": "l10-fixed-inspector", "materials": decisions})
            artifact = self.canonical.reconstruct_t1(bundle_id=bundle["bundle_id"])
            if selection is None or artifact is None:
                raise ValueError("T1 selection/reconstruction capacity")
            cutover = None
            if request["activate"]:
                cutover = self.canonical.cutover_reentry(artifact_id=artifact["artifact_id"],
                    expected_active_model_ref=artifact["parent_model_ref"], operator="l10-explicit-harness",
                    basis="apply inspected sensory relations", evidence=learning_id)
                if cutover is None:
                    raise ValueError("cutover capacity")
            response = {"status": "activated" if cutover else "reconstructed_inactive_control",
                        "inspections": inspections, "candidates": candidates, "bundle": bundle,
                        "selection": selection, "artifact": artifact, "cutover": cutover}
        self._learning[learning_id] = {"request": deepcopy(request), "response": deepcopy(response)}
        return deepcopy(response)

    def snapshot(self):
        return {"schema": "luanti-sensory-learning-l10-v1", "operations": deepcopy(self._operations),
                "results": deepcopy(self._results), "learning": deepcopy(self._learning),
                "capacity": MAX_OPERATIONS, "purpose": PURPOSE}

    def _check_agent(self, request):
        if self.agent_id is not None and request.get("agent_id") != self.agent_id:
            raise ValueError("foreign agent")


class MultiAgentSensoryFoodLearning:
    """L10B: fixed A/B ownership; separate budgets and receipts, shared World store.

    The bridge serializes calls with its canonical lock. Agent/decision binding
    prevents accidental callback crossover; it is not network authentication.
    """

    def __init__(self, sensory, canonical, *, context=CONTEXT):
        self._agents = {agent: SensoryFoodLearning(sensory, canonical, agent_id=agent, context=context)
                        for agent in ("npc_a", "npc_b")}

    def _route(self, request):
        agent = request.get("agent_id")
        if not isinstance(agent, str) or agent not in self._agents:
            raise ValueError("unknown learning agent")
        return self._agents[agent]

    def decide(self, request):
        return self._route(request).decide(request)

    def record(self, request):
        return self._route(request).record(request)

    def learn(self, request):
        return self._route(request).learn(request)

    def snapshot(self):
        return {"schema": "luanti-sensory-learning-l10b-v1", "purpose": PURPOSE,
                "capacity_per_agent": MAX_OPERATIONS, "capacity_total": 2 * MAX_OPERATIONS,
                "by_agent": {agent: loop.snapshot() for agent, loop in self._agents.items()}}


class SharedFoodLearning(MultiAgentSensoryFoodLearning):
    """L10C: apparatus chosen at startup, never by a decision request or cue."""

    def __init__(self, sensory, canonical):
        super().__init__(sensory, canonical, context=SHARED_CONTEXT)

    def snapshot(self):
        return dict(super().snapshot(), schema="luanti-sensory-learning-l10c-v1", context=SHARED_CONTEXT)
