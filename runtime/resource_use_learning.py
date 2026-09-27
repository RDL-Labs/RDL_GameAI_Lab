"""L12: own Experience -> independently inspected relation -> active M_B -> warning.

Finite instrumented fixture, process-local journal. No relationship label is
learned and no World return schedule is an interpretation input.
"""
from copy import deepcopy
from math import isfinite
from threading import RLock

from .boundary_defense import (BoundaryDefense, LIMITATION, SCOPE, UNIT, integer,
                              keys, label, reaction_step, require, same, validate_display_receipt)
from .sensory_food_learning import identity, comparison

SCHEMA = "l12-resource-use-learning-v1"
PURPOSE = "predict-own-pickup-after-peer-use"
CONTEXT = "l12-return-or-hold-apparatus-v1"
RELATION = "resource-use-continuation-v1"
ADAPTER = "l12-direct-pickup-v1"
CONSUMER = "l12-fixed-continuation-warning-v1"


def boundary(config):
    return {**{k: config[k] for k in SCOPE}, "agent_id": config["defender"],
            "purpose": PURPOSE, "context": CONTEXT, "action": "observed_unit_taken",
            "profile": deepcopy(config["profile"]), "adapter_revision": ADAPTER,
            "own_procedure": "one-pickup-within-radius-1.25",
            "own_offset_us": 2_000_000, "own_slot_us": 250_000}


def interpret(model, section):
    keys(section, "section_id boundary tick phase outcome reasons capture_us pose_ref coverage source_ids dimensions")
    b = section["boundary"]
    require(b["agent_id"] == model.agent_id and b["purpose"] == PURPOSE and b["context"] == CONTEXT,
            "interpretation_scope")
    require(section["phase"] in ("before", "after"), "interpretation_phase")
    result = {"model_ref": model.model_ref, "section_id": section["section_id"], "tick": section["tick"],
              "boundary": deepcopy(b), "status": "unknown", "values": None,
              "source_candidates": [], "reasons": deepcopy(section["reasons"])}
    if result["reasons"]:
        result["status"] = "unavailable"
        return result
    if section["phase"] == "after":
        require(type(section["outcome"]) is bool, "observed_outcome_required")
        value = section["outcome"]
    else:
        matches = [r for r in model.adopted_relations if r["relation"].get("kind") == RELATION
                   and same(r["relation"].get("boundary"), b)]
        if not matches:
            # A typed relation for another applicability boundary is not a negative prediction.
            typed = [r for r in model.adopted_relations if r["relation"].get("kind") == RELATION]
            result.update(status="unavailable" if typed else "unknown",
                          reasons=["applicability_mismatch" if typed else "unlearned_condition"])
            return result
        values = [r["relation"].get("predicts_acquired") for r in matches]
        if any(type(v) is not bool for v in values) or len(set(values)) != 1:
            result.update(status="unavailable", reasons=["conflicting_relations"])
            return result
        value = values[0]
        result["source_candidates"] = [r["source_candidate_id"] for r in matches]
    result.update(status="known", values={"own_food_acquired": float(value)})
    return result


def inspect_experiences(formation, validation):
    """Three independent formation votes and three held-out checks, never six votes."""
    require(len(formation) == len(validation) == 3, "three_plus_three_required")
    all_e = formation + validation
    for field in ("record_id", "episode_id", "event_id", "operation_id"):
        require(len({e[field] for e in all_e}) == 6, "source_alias")
    b = formation[0]["section"]["boundary"]
    comparable = lambda e: (not e["section"]["reasons"] and type(e["acquired"]) is bool
                            and same(e["section"]["boundary"], b))
    form_ok = all(comparable(e) for e in formation)
    unanimous = form_ok and len({e["acquired"] for e in formation}) == 1
    expected = formation[0]["acquired"] if unanimous else None
    diagnostics = [{"experience_id": e["record_id"], "comparable": comparable(e),
                    "agrees": e["acquired"] == expected if comparable(e) and unanimous else None,
                    "reasons": list(e["section"]["reasons"]) +
                    ([] if same(e["section"]["boundary"], b) else ["context_mismatch"])} for e in validation]
    count = sum(d["comparable"] for d in diagnostics)
    disposition = "DEFER" if not unanimous or count != 3 else (
        "RETAIN" if all(d["agrees"] for d in diagnostics) else "REJECT")
    candidate = None
    if unanimous:
        signature = {"kind": RELATION, "boundary": deepcopy(b), "predicts_acquired": expected,
                     "formation_experiences": [e["record_id"] for e in formation],
                     "validation_experiences": [e["record_id"] for e in validation]}
        candidate = {"candidate_id": identity("l12-candidate:", signature), "agent_id": b["agent_id"],
                     "support_count": 3, "common_relation_signature": signature}
    return {"formation_status": "candidate_formed" if unanimous else (
                "no_candidate" if form_ok else "formation_unavailable"),
            "formation_support": 3 if unanimous else 0, "candidate": candidate,
            "validation_requested": 3, "comparable_count": count,
            "validation_count": 3 if count == 3 else None,
            "disposition": disposition, "validation_results": diagnostics}


class ResourceUseLearning:
    def __init__(self, run_id, canonical):
        require(label(run_id), "invalid_run")
        self.run_id, self.canonical = run_id, canonical
        self.lock = RLock()
        self._validator = BoundaryDefense(run_id)
        self._models = {}
        self._reaction_model = None
        self._state = {"schema": SCHEMA, "config": None, "episodes": {}, "learning": None,
                       "review": None, "reaction": None, "permit": None, "results": {}, "load": 0}

    def snapshot(self):
        with self.lock:
            return deepcopy(self._state)

    def configure(self, config):
        with self.lock:
            keys(config, "schema run_id world_epoch defender actor site_ref clock_id registration profile")
            require(config["schema"] == SCHEMA, "config_schema")
            # Reuse L11's reference/profile checks; no inclusion is fabricated or consulted.
            validation = dict(config, schema="l11-boundary-defense-v1", relation=None,
                reaction={"profile_id": "l12-base", "source": CONSUMER, "base_threshold": 3},
                site_relation={"source": CONTEXT, "continued_use": True})
            self._validator.configure(validation)
            old = self._state["config"]
            require(old is None or same(old, config), "config_conflict")
            self._state["config"] = deepcopy(config)
            return {"configured": True, "run_id": self.run_id}

    def _section(self, source, capture, reasons, record, phase="before", outcome=None):
        notice = record.get("notice")
        before = record["before"]
        return {"section_id": source, "boundary": boundary(self._state["config"]),
                "tick": capture // 250000, "capture_us": capture,
                "pose_ref": notice["pose_ref"] if notice else (before["pose_ref"] if before else None),
                "coverage": {"receipt": notice["coverage"] if notice else record["coverage"],
                             **{side: record[side]["coverage"] if record[side] else None for side in ("before", "after")}},
                "source_ids": {"event_id": notice["event_id"] if notice else record["event_id"],
                               **{side: record[side]["packet_id"] if record[side] else None for side in ("before", "after")}},
                "dimensions": ["own_food_acquired"],
                "phase": phase, "outcome": outcome, "reasons": reasons}

    @staticmethod
    def _interpret(model, section):
        if model is not None:
            return model.interpret_resource_use(section)
        return {"model_ref": None, "section_id": section["section_id"], "tick": section["tick"],
                "boundary": deepcopy(section["boundary"]), "status": "unavailable", "values": None,
                "source_candidates": [], "reasons": section["reasons"] + ["model_unavailable"]}

    def _capture(self, packet):
        if packet is None or packet["coverage"] != "complete":
            return
        visible = packet["visible"]
        self.canonical.capture({"observation_id": packet["packet_id"], "agent_id": packet["observer"],
            "tick": packet["capture_us"] // 250000, "observation": {
                "perception_rule": "l12-bounded-local-radius-12",
                "visible_agents": [{"id": v["ref"]} for v in visible if v["kind"] == "npc"],
                "visible_objects": [{"id": v["ref"]} for v in visible if v["kind"] == "food"],
                "visible_places": []}})

    def observe(self, request):
        with self.lock:
            keys(request, "episode_id scheduled_us now_us record")
            s = self._state; c = s["config"]
            require(c is not None, "unconfigured")
            require(label(request["episode_id"]) and integer(request["scheduled_us"]) and integer(request["now_us"]), "invalid_episode")
            reasons = self._validator._sources(request["record"], c, require_relation=False)
            n = request["record"]["notice"]; episode = request["episode_id"]
            frozen = {k: deepcopy(v) for k, v in request.items() if k != "now_us"}
            require(request["now_us"] >= n["capture_us"], "future_capture")
            old = s["episodes"].get(episode)
            if old:
                require(same(old["request"], frozen), "episode_conflict")
                return {"new_event": False, "receipt": deepcopy(old["receipt"])}
            require(s["learning"] is None or s["reaction"] is not None, "learning_frozen")
            require(len(s["episodes"]) < 8, "episode_capacity")
            require(s["reaction"] is None or not any(e["reaction"] for e in s["episodes"].values()), "reaction_capacity")
            for entry in s["episodes"].values():
                if entry["own"]:
                    require(n["event_id"] != entry["own"]["request"]["event_id"], "event_alias")
            previous = [e["request"]["record"]["notice"] for e in s["episodes"].values()]
            for p in previous:
                require(not any(n[k] == p[k] for k in ("notice_id", "event_id", "unit_ref", "seq")), "source_alias")
            require(not previous or (n["seq"] > max(p["seq"] for p in previous)
                    and n["capture_us"] > max(p["capture_us"] for p in previous)), "capture_reversed")
            require(request["scheduled_us"] <= n["capture_us"] < request["scheduled_us"] + 250000, "missed_peer_slot")
            require(request["now_us"] <= n["capture_us"] + 500000, "admission_expired")
            self._check_packet_alias([n["before_id"], n["after_id"]])
            # Shared count path receives the very same accepted bounded packets.
            self._capture(request["record"]["before"]); self._capture(request["record"]["after"])
            models = self.canonical.snapshot()["models"]
            model = self._reaction_model or (self.canonical.model_for_agent(c["defender"])
                      if any(m["agent_id"] == c["defender"] for m in models.values()) else None)
            section = self._section(n["notice_id"], n["capture_us"], reasons, request["record"])
            prediction = self._interpret(model, section)
            receipt = {"notice_id": n["notice_id"], "section": section, "prediction": prediction,
                       "status": "training_disabled", "basis": "training_reaction_disabled",
                       "evaluation": None, "permit": None, "consumer": CONSUMER,
                       "adoption": deepcopy(s["reaction"])}
            if s["reaction"]:
                if prediction["status"] == "unavailable":
                    receipt.update(status="unavailable", basis="interpretation_unavailable")
                else:
                    positive = prediction["status"] == "known" and prediction["values"]["own_food_acquired"] == 1
                    receipt.update(status="evaluated", basis="learned_continuation_allowance" if positive else (
                        "learned_noncontinuation" if prediction["status"] == "known" else "baseline_unlearned"))
                    receipt["evaluation"] = reaction_step(0, 0, (11 if positive else 3) * UNIT)
                    s["load"] = receipt["evaluation"]["load_after"]
                    if receipt["evaluation"]["threshold_reached"]:
                        permit = {k: c[k] for k in SCOPE}
                        permit.update(operation_id=n["notice_id"] + ":warning", notice_id=n["notice_id"],
                            capture_us=n["capture_us"], expires_us=n["capture_us"] + UNIT, duration_us=250000)
                        receipt["permit"] = permit; s["permit"] = deepcopy(permit)
            s["episodes"][episode] = {"request": frozen, "receipt": deepcopy(receipt), "own": None,
                                       "reaction": s["reaction"] is not None}
            self._models[episode] = model
            return {"new_event": True, "receipt": deepcopy(receipt)}

    def _check_packet_alias(self, ids):
        require(len(set(ids)) == len(ids), "packet_alias")
        existing = set()
        for e in self._state["episodes"].values():
            for record in [e["request"]["record"]] + ([e["own"]["request"]] if e["own"] else []):
                existing.update(record[side]["packet_id"] for side in ("before", "after") if record[side])
        require(not existing.intersection(ids), "packet_alias")

    def _own_sources(self, r, e):
        c = self._state["config"]; n = e["request"]["record"]["notice"]
        require(r["notice_id"] == n["notice_id"], "result_binding")
        require(all(label(r[k]) for k in ("operation_id", "event_id")), "result_identity")
        require(all(integer(r[k]) for k in ("capture_us", "now_us")), "result_time")
        require(e["request"]["scheduled_us"] + 2000000 <= r["capture_us"] < e["request"]["scheduled_us"] + 2250000, "missed_own_slot")
        require(type(r["attempted"]) is bool and (type(r["acquired"]) is bool if r["attempted"] else r["acquired"] is None), "unattempted_not_failure")
        require(r["coverage"] in ("complete", "partial"), "invalid_coverage")
        reasons = list(e["receipt"]["section"]["reasons"])
        if not r["attempted"]: reasons.append("not_attempted")
        if r["coverage"] != "complete": reasons.append("own_acquisition_incomplete")
        packets = []
        for side, order in (("before", 1), ("after", 3)):
            p = r[side]
            if p is None:
                reasons.append("own_source_missing"); continue
            keys(p, "packet_id observer capture_us seq order pose_ref profile coverage visible")
            require(label(p["packet_id"]) and p["observer"] == c["defender"] and
                    all(integer(p[k]) for k in ("capture_us", "seq", "order")) and
                    p["capture_us"] == r["capture_us"] and p["seq"] == n["seq"] and p["order"] == order
                    and p["pose_ref"] == n["pose_ref"] and same(p["profile"], c["profile"]), "own_packet_binding")
            require(p["coverage"] in ("complete", "partial"), "invalid_coverage")
            if p["coverage"] != "complete": reasons.append("own_acquisition_incomplete")
            require(isinstance(p["visible"], list) and len(p["visible"]) <= 2, "visible_budget")
            refs = set()
            for v in p["visible"]:
                keys(v, "ref kind distance relative_position"); keys(v["relative_position"], "x y z")
                require(v["ref"] not in refs and v["ref"] in (c["actor"], n["unit_ref"]), "visible_reference")
                refs.add(v["ref"])
                require(v["kind"] == ("npc" if v["ref"] == c["actor"] else "food"), "visible_kind")
                xyz = list(v["relative_position"].values())
                require(all(type(x) in (int, float) and isfinite(x) for x in xyz + [v["distance"]])
                        and 0 <= v["distance"] <= 12 and abs(sum(x*x for x in xyz)**.5-v["distance"]) < .0001, "invalid_distance")
            if c["actor"] not in refs: reasons.append("actor_not_visible")
            packets.append((side, refs))
        effect = r["effect"]
        if effect is None:
            reasons.append("own_source_missing")
        else:
            keys(effect, "source observer event_id operation_id notice_id capture_us attempted acquired hand_before hand_after")
            require(effect["source"] == ADAPTER and effect["observer"] == c["defender"] and
                    all(same(effect[k], r[k]) for k in ("event_id", "operation_id", "notice_id", "capture_us", "attempted", "acquired")), "own_effect_binding")
            require(integer(effect["hand_before"]) and integer(effect["hand_after"]) and effect["hand_before"] == 0
                    and effect["hand_after"] == int(r["acquired"] is True), "own_hand_evidence")
        if not reasons:
            for side, refs in packets:
                require((n["unit_ref"] in refs) == (side == "before" and r["acquired"]), "own_pickup_evidence")
                if side == "before" and r["acquired"]:
                    require(next(v["distance"] for v in r[side]["visible"] if v["ref"] == n["unit_ref"]) <= 1.25, "pickup_outside_radius")
        return sorted(set(reasons))

    def record(self, r):
        with self.lock:
            keys(r, "episode_id notice_id operation_id event_id capture_us now_us attempted acquired coverage before after effect")
            s = self._state
            require(r["episode_id"] in s["episodes"], "unknown_episode")
            e = s["episodes"][r["episode_id"]]
            reasons = self._own_sources(r, e)
            frozen = {k: deepcopy(v) for k, v in r.items() if k != "now_us"}
            require(r["now_us"] >= r["capture_us"], "future_capture")
            if e["own"]:
                require(same(frozen, e["own"]["request"]), "result_conflict")
                return {"new_result": False, "receipt": deepcopy(e["own"]["receipt"])}
            require(s["learning"] is None or e["reaction"], "learning_frozen")
            require(r["now_us"] <= e["request"]["scheduled_us"] + 3000000, "result_admission_expired")
            for other in s["episodes"].values():
                require(r["event_id"] != other["request"]["record"]["notice"]["event_id"], "event_alias")
                if other["own"]:
                    require(all(r[k] != other["own"]["request"][k] for k in ("event_id", "operation_id")), "event_alias")
            self._check_packet_alias([r[side]["packet_id"] for side in ("before", "after") if r[side]])
            section = self._section(r["event_id"], r["capture_us"], reasons, r, "after", r["acquired"] if not reasons else None)
            after = self._interpret(self._models[r["episode_id"]], section)
            experience = {"record_id": identity("l12-experience:", [self.run_id, r["event_id"]]),
                "agent_id": s["config"]["defender"], "episode_id": r["episode_id"], "event_id": r["event_id"],
                "operation_id": r["operation_id"], "notice_id": r["notice_id"], "section": section,
                "acquired": r["acquired"] if not reasons else None}
            receipt = {"experience": experience, "F_prime": after,
                       "comparison": comparison(e["receipt"]["prediction"], after)}
            self._capture(r["before"]); self._capture(r["after"])
            e["own"] = {"request": frozen, "receipt": deepcopy(receipt)}
            return {"new_result": True, "receipt": deepcopy(receipt)}

    def review(self, request):
        with self.lock:
            keys(request, "episode_id reviewer basis evidence")
            s = self._state
            if s["review"]:
                require(same(request, s["review"]["request"]), "review_conflict")
                return deepcopy(s["review"]["receipt"])
            require(all(label(request[k]) for k in request), "invalid_review")
            require(request["episode_id"] in s["episodes"], "unknown_episode")
            require(request["episode_id"] == next(iter(s["episodes"])), "review_first_episode_required")
            e = s["episodes"][request["episode_id"]]; n = e["request"]["record"]["notice"]
            require(not e["receipt"]["section"]["reasons"], "review_source_unavailable")
            snapshot = self.canonical.snapshot()
            ids = [p["assessment_id"] for p in snapshot["review_path"]["paths"]
                   if p["F"]["source_observation_id"] == n["before_id"]
                   and p["F_prime"]["source_observation_id"] == n["after_id"]]
            matches = [a for a in snapshot["assessment"]["records"] if a["assessment_id"] in ids]
            require(len(matches) == 1, "review_binding")
            a = matches[0]
            require(a["E"]["deltas"] == {"visible_agents_count": 0., "visible_objects_count": -1., "visible_places_count": 0.}, "review_count_difference")
            payload = {"assessment_id": a["assessment_id"], "expected_revision": 0,
                **{k: request[k] for k in ("reviewer", "basis", "evidence")},
                "dimensions": {k: {"status": "unresolved", "residual": 1.} if v else {"status": "zero"}
                               for k, v in a["E"]["deltas"].items()}}
            receipt = self.canonical.review_assessment(payload)
            s["review"] = {"request": deepcopy(request), "receipt": receipt}
            return deepcopy(receipt)

    def learn(self, request):
        with self.lock:
            keys(request, "learning_id formation_episodes validation_episodes activate")
            require(label(request["learning_id"]) and type(request["activate"]) is bool, "learning_identity")
            s = self._state; j = s["learning"]
            if j:
                require(same(j["request"], request), "learning_conflict")
                if j["phase"] == "complete": return deepcopy(j)
            else:
                f, v = request["formation_episodes"], request["validation_episodes"]
                require(isinstance(f, list) and isinstance(v, list) and len(f) == len(v) == 3, "three_plus_three_required")
                require(all(label(x) for x in f+v) and len(set(f+v)) == 6, "source_alias")
                require(all(x in s["episodes"] and s["episodes"][x]["own"] for x in f+v), "missing_experience")
                require(s["review"] is not None, "explicit_review_required")
                experiences = [deepcopy(s["episodes"][x]["own"]["receipt"]["experience"]) for x in f+v]
                inspection = inspect_experiences(experiences[:3], experiences[3:])
                j = {"request": deepcopy(request), "phase": "prepared", "inspection": inspection,
                     "experiences": experiences, "bundle": None, "selection": None, "artifact": None, "cutover": None}
                s["learning"] = j
            # Each successful stage is journaled. Reconcile a selection that committed
            # before its return was lost (selection's expected_revision is not replayable).
            if j["bundle"] is None:
                candidate = j["inspection"]["candidate"]
                b = self.canonical.expand_t1_materials(assessment_id=s["review"]["receipt"]["assessment_id"],
                    candidates=[candidate] if candidate else [], experiences=j["experiences"])
                require(b is not None, "T1_capacity")
                j.update(bundle=b, phase="expanded")
            if j["selection"] is None:
                decisions = [{"material_id": m["material_id"],
                    "disposition": "RETAIN" if m["kind"] == "current_M_B" else (
                        j["inspection"]["disposition"] if m["kind"] == "CandidateRelation" else "DEFER"),
                    "basis": "retain-parent" if m["kind"] == "current_M_B" else (
                        "L12-held-out-unanimity" if m["kind"] == "CandidateRelation" else "L12-material-out-of-scope"),
                    "evidence": request["learning_id"]} for m in j["bundle"]["materials"]]
                existing = [x for x in self.canonical.t1_selection.snapshot()["records"] if x["bundle_id"] == j["bundle"]["bundle_id"]]
                if existing:
                    selection = existing[0]
                    require(selection["revision"] == 1 and selection["reviewer"] == "l12-fixed-inspector" and
                            [{k: d[k] for k in ("material_id", "disposition", "basis", "evidence")} for d in selection["materials"]] == decisions,
                            "selection_conflict")
                else:
                    selection = self.canonical.inspect_t1_materials(bundle_id=j["bundle"]["bundle_id"], payload={
                        "expected_revision": 0, "reviewer": "l12-fixed-inspector", "materials": decisions})
                require(selection is not None, "T1_selection_capacity")
                j.update(selection=selection, phase="selected")
            if j["inspection"]["disposition"] == "RETAIN":
                if j["artifact"] is None:
                    artifact = self.canonical.reconstruct_t1(bundle_id=j["bundle"]["bundle_id"])
                    require(artifact is not None, "T1_reconstruction_capacity")
                    j.update(artifact=artifact, phase="reconstructed")
                if request["activate"] and j["cutover"] is None:
                    cutover = self.canonical.cutover_reentry(artifact_id=j["artifact"]["artifact_id"],
                        expected_active_model_ref=j["artifact"]["parent_model_ref"], operator="l12-explicit-harness",
                        basis="activate independently inspected resource-use relation", evidence=request["learning_id"])
                    require(cutover is not None, "cutover_capacity")
                    j.update(cutover=cutover, phase="activated")
            j["phase"] = "complete"
            return deepcopy(j)

    def begin(self, request):
        with self.lock:
            keys(request, "operation_id learning_id")
            require(all(label(x) for x in request.values()), "invalid_begin")
            s = self._state; j = s["learning"]
            require(j is not None and j["phase"] == "complete" and request["learning_id"] == j["request"]["learning_id"], "learning_incomplete")
            if s["reaction"]:
                require(same(s["reaction"]["request"], request), "begin_conflict")
                return deepcopy(s["reaction"])
            model = self.canonical.model_for_agent(s["config"]["defender"])
            expected = j["artifact"]["model_ref"] if j["cutover"] else j["bundle"]["model_ref"]
            require(model.model_ref == expected, "reaction_model_changed")
            self._reaction_model = model
            s["reaction"] = {"request": deepcopy(request), "model_ref": model.model_ref,
                "candidate": deepcopy(j["inspection"]["candidate"]), "selection_id": j["selection"]["selection_id"],
                "artifact_id": j["artifact"]["artifact_id"] if j["artifact"] else None,
                "cutover": deepcopy(j["cutover"]), "base_threshold": 3, "initial_load": 0}
            return deepcopy(s["reaction"])

    def result(self, request):
        with self.lock:
            response = validate_display_receipt(request, self._state["permit"], self._state["results"])
            self._state["results"][response["operation_id"]] = deepcopy(request)
            return response
