"""L13V: a finite landmark-relative survey and an inspected no-discovery M_B relation.

Out-and-back movement is supplied probe control. Only accepted observations and
measured effects form learning material; no World identity or coordinates enter.
"""
from copy import deepcopy
from math import sin, cos, radians, hypot

from .exploration import NEIGHBORHOOD_SCHEMA, fields, require, integer
from .exploration_series import digest
from .landmark_exploration import LandmarkExplorationDay, initial_state, compatible
from .learned_exploration import (LearnedExplorationDay, LearnedExplorationSeries, observation_key,
    make_candidate as food_candidate, inspect_day as inspect_food, canonical_state as food_canonical, projection)
from .v23_interpretation import GameAIFrozenComparisonSidecar

RELATION = "l13v-completed-neighborhood-no-food-v1"
PURPOSE = "food-discovery-during-bounded-neighborhood-survey"
PLAN = "two-lateral-out-and-back-2step-v1"
MAX_SURVEY_US = 5_000_000
# Each eight-operation excursion returns to its initial heading and viewpoint.
SURVEY = [("turn", -90), ("move", 1), ("move", 1), ("turn", 90),
          ("turn", 90), ("move", 1), ("move", 1), ("turn", -90),
          ("turn", 90), ("move", 1), ("move", 1), ("turn", 90),
          ("turn", 90), ("move", 1), ("move", 1), ("turn", 90)]


def descriptor(f):
    return {k: deepcopy(f[k]) for k in ("color", "azimuth", "range_band")}


def interpret(model, section):
    fields(section, "series_id agent_id purpose observed anchor plan max_survey_us food_observed")
    require(section["agent_id"] == model.agent_id and section["purpose"] == PURPOSE, "neighborhood_boundary")
    require(type(section["food_observed"]) is bool, "food_observed")
    result = dict(model_ref=model.model_ref, status="unknown", predicts_food=None, source_candidate=None,
                  reason="no_matching_inspected_relation")
    if section["observed"] is None:
        return dict(result, reason="acquisition_incomplete")
    if section["food_observed"]:
        return dict(result, reason="goal_already_observed")
    matches = [r for r in model.adopted_relations if r["relation"].get("kind") == RELATION
               and all(r["relation"].get(k) == section[k] for k in
                       ("series_id", "purpose", "plan", "max_survey_us"))
               and r["relation"]["start_observed"] == section["observed"]
               and r["relation"]["anchor"] == section["anchor"]]
    if len(matches) == 1:
        result.update(status="known", predicts_food=False, source_candidate=matches[0]["source_candidate_id"],
                      reason="inspected_finite_no_discovery; not-place-absence")
    elif matches:
        result["reason"] = "ambiguous_relations"
    return result


def local_state():
    return dict(phase="idle", outcome=None, survey=None, prediction=None)


def survey_outcome(state, start, end, anchor):
    """Recheck the completed plan from accepted observations/results, not a status label."""
    ps = list(state["observations"].values())[start:end+1]
    if len(ps) != 17 or any(observation_key(p) is None for p in ps):
        return "incomplete"
    if ps[-1]["capture_us"]-ps[0]["capture_us"] > MAX_SURVEY_US:
        return "incomplete"
    x = y = z = yaw = 0.
    for i, (p, after) in enumerate(zip(ps, ps[1:])):
        c = state["commands"].get(p["observation_id"])
        r = state["results"].get("op:"+p["observation_id"])
        if (c is None or r is None or [c["kind"], c["amount"]] != list(SURVEY[i])
                or r["status"] != ("moved" if SURVEY[i][0] == "move" else "turned")
                or r["after_pose_ref"] != after["pose_ref"] or r["after_revision"] != after["body_revision"]
                or not p["capture_us"] <= r["executed_us"] < after["capture_us"]):
            return "incomplete"
        theta = radians(yaw)
        x += sin(theta)*r["forward"]+cos(theta)*r["right"]
        z += cos(theta)*r["forward"]-sin(theta)*r["right"]
        y += r["up"]; yaw += r["yaw"]
        if i in (7, 15):
            matches = [f for f in after["landmarks"]["features"] if f["range_band"] == "near" and compatible(f, anchor, (yaw+180)%360-180, 15)]
            if hypot(x, y, z) > .001 or abs((yaw+180)%360-180) > .01 or len(matches) != 1:
                return "incomplete"
    return "food_observed" if any(p["food"]["visible"] for p in ps) else "completed_no_food"


class NeighborhoodExplorationDay(LandmarkExplorationDay):
    allow_neighborhood = True
    configuration_schema = NEIGHBORHOOD_SCHEMA

    def _begin(self, p, landmark):
        anchor = descriptor(landmark["goal"]["current_feature"])
        prediction = self._model(p).interpret_neighborhood(dict(series_id=self.series_id, agent_id=p["agent_id"],
            purpose=PURPOSE, observed=observation_key(p), anchor=anchor, plan=PLAN, max_survey_us=MAX_SURVEY_US,
            food_observed=bool(p["food"]["visible"])))
        n = dict(phase="survey", outcome=None, prediction=prediction, survey=dict(
            survey_id=p["observation_id"]+":survey", start_index=len(self.observations),
            source_observation=p["observation_id"], source_pose=p["pose_ref"], start_us=p["capture_us"],
            anchor=anchor, start_observed=observation_key(p), cursor=0, odometry=[0., 0., 0., 0.],
            food_seen=bool(p["food"]["visible"]), return_sources=[]))
        if prediction["status"] == "known" and prediction["predicts_food"] is False:
            n.update(phase="skipped", outcome="active_M_B_no_food")
            return ["wait", 0], n
        landmark["stage"] = "survey"
        return list(SURVEY[0]), n

    def _survey(self, p, n, landmark):
        s = n["survey"]
        def stop(reason):
            n.update(phase="incomplete", outcome=reason)
            landmark["stage"] = "terminated"
            return ["wait", 0], n
        if observation_key(p) is None:
            return stop("acquisition_incomplete")
        if p["capture_us"]-s["start_us"] > MAX_SURVEY_US:
            return stop("survey_deadline")
        previous = next(reversed(self.observations.values()))
        r = self.results.get("op:"+previous["observation_id"])
        if (r is None or r["after_pose_ref"] != p["pose_ref"] or r["after_revision"] != p["body_revision"]
                or r["executed_us"] >= p["capture_us"]):
            return stop("body_correspondence_unavailable")
        if r["status"] != ("moved" if SURVEY[s["cursor"]][0] == "move" else "turned"):
            return stop("blocked" if r["status"] == "blocked" else "operation_not_executed")
        x, y, z, yaw = s["odometry"]; theta = radians(yaw)
        s["odometry"] = [x+sin(theta)*r["forward"]+cos(theta)*r["right"], y+r["up"],
                         z+cos(theta)*r["forward"]-sin(theta)*r["right"], yaw+r["yaw"]]
        s["food_seen"] |= bool(p["food"]["visible"])
        s["cursor"] += 1
        if s["cursor"] in (8, 16):
            x, y, z, yaw = s["odometry"]
            if hypot(x, y, z) > .001 or abs((yaw+180)%360-180) > .01:
                return stop("return_not_confirmed")
            matches = [f for f in p["landmarks"]["features"]
                       if f["range_band"] == "near" and compatible(f, s["anchor"], (yaw+180)%360-180, 15)]
            if len(matches) != 1:
                return stop("anchor_lost" if not matches else "anchor_ambiguous")
            s["return_sources"].append(dict(observation_id=p["observation_id"], pose_ref=p["pose_ref"],
                                            capture_us=p["capture_us"], feature_ref=matches[0]["ref"]))
        if s["cursor"] == len(SURVEY):
            n.update(phase="completed", outcome="food_observed" if s["food_seen"] else "completed_no_food")
            s["end_index"] = len(self.observations)
            s["terminal_source"] = p["observation_id"]
            landmark["stage"] = "terminated"
            return ["wait", 0], n
        return list(SURVEY[s["cursor"]]), n

    def _decision(self, p):
        d = LearnedExplorationDay._decision(self, p)
        last = next(reversed(self.decisions.values())) if self.decisions else None
        landmark = deepcopy(last["landmark"]) if last else initial_state()
        n = deepcopy(last["neighborhood"]) if last else local_state()
        landmark["selection_index"] = None
        if d["reason"] in ("active_M_B", "validation_probe", "active_M_B_terminal_observation", "validation_probe_terminal_observation"):
            landmark.update(stage="suspended", outcome="episodic_route_authority")
            n.update(phase="suspended", outcome=d["reason"])
        elif d["reason"] == "observed_food_in_reach":
            landmark.update(stage="terminated", outcome="food_pickup_priority")
            n.update(phase="incomplete", outcome="food_pickup_priority")
        else:
            if n["phase"] == "survey":
                action, n = self._survey(p, n, landmark)
            else:
                action, landmark = self._subgoal(p)
                n = local_state()
                if landmark["outcome"] == "near_feature_observed":
                    action, n = self._begin(p, landmark)
            reason = ("neighborhood_"+(n["outcome"] or n["phase"]) if n["phase"] != "idle"
                      else "landmark_"+(landmark["outcome"] or landmark["stage"]))
            d.update(action=action, reason=reason, target="")
        d.update(landmark=landmark, neighborhood=n, bootstrap_action=None)
        return d


def make_candidate(state, episode, series_id):
    positive = food_candidate(state, episode, series_id)
    if positive: return positive
    records = list(state["observations"].values())
    for decision in state["decisions"].values():
        n = decision["neighborhood"]
        if n["outcome"] != "completed_no_food": continue
        survey = n["survey"]; end = survey["end_index"]
        if survey_outcome(state, survey["start_index"], end, survey["anchor"]) != "completed_no_food": continue
        trace = []
        for p, after in zip(records[:end], records[1:end+1]):
            c = state["commands"][p["observation_id"]]; r = state["results"].get(c["operation_id"])
            if (observation_key(p) is None or r is None or r["status"] not in ("moved", "turned", "blocked", "waited")
                    or r["after_pose_ref"] != after["pose_ref"] or r["after_revision"] != after["body_revision"]
                    or r["executed_us"] >= after["capture_us"]):
                break
            trace.append(dict(observed=observation_key(p), action=[c["kind"], c["amount"]], result_status=r["status"],
                result_up=r["up"], source_observation=p["observation_id"], source_operation=c["operation_id"],
                source_capture_us=p["capture_us"], source_pose=p["pose_ref"]))
        if len(trace) != end or observation_key(records[end]) is None: continue
        relation = dict(kind=RELATION, series_id=series_id, purpose=PURPOSE, plan=PLAN, max_survey_us=MAX_SURVEY_US,
            predicts_food=False, start_observed=survey["start_observed"], anchor=survey["anchor"],
            survey_start_index=survey["start_index"], survey_evidence=deepcopy(survey), trace=trace,
            terminal_observed=observation_key(records[end]), terminal_source=records[end]["observation_id"],
            formation_episode=episode, formation_run=state["config"]["run_id"], formation_seed=state["seed"],
            scope="one completed two-excursion survey; not-place-absence-or-all-future-search")
        return dict(candidate_id="l13v-candidate:"+digest(relation)[:24], agent_id="npc_a", support_count=1,
                    common_relation_signature=relation)
    return None


def inspect_day(candidate, state, episode):
    relation = candidate["common_relation_signature"]
    result = inspect_food(candidate, state, episode)  # same independent Episode and prefix/body checks
    if relation["kind"] != RELATION: return result
    if result["disposition"] == "DEFER": return result
    outcome = survey_outcome(state, relation["survey_start_index"], len(relation["trace"]), relation["anchor"])
    if outcome == "incomplete":
        return dict(result, disposition="DEFER", reason="survey_budget_unmatched")
    found = outcome == "food_observed"
    return dict(result, disposition="REJECT" if found else "RETAIN",
                reason="held_out_food_counterexample" if found else "held_out_complete_survey_no_food")


def patch_projection(p, series_id, day):
    packet = projection(p, series_id, day)
    packet["observation"]["perception_rule"] = "l13v-observed-patch-count:"+series_id
    packet["observation"]["visible_objects"] = [dict(id=f["ref"]) for f in p["landmarks"]["features"]]
    return packet


def canonical_state(series_id, days, candidate, inspection, activate):
    if candidate and candidate["common_relation_signature"]["kind"] != RELATION:
        return food_canonical(series_id, days, candidate, inspection, activate)
    sidecar, learning = GameAIFrozenComparisonSidecar(), None
    for index, day in enumerate(days, 1):
        ps = list(day["state"]["observations"].values())
        # Actual observed patch-count difference, never invented expected Food.
        complete = [p for p in ps if observation_key(p) is not None]
        selected = complete[:1]
        if selected:
            selected += [p for p in complete[1:] if len(p["landmarks"]["features"]) != len(selected[0]["landmarks"]["features"])][:1]
        for p in selected: sidecar.capture(patch_projection(p, series_id, index))
        if not inspection or day["episode_id"] != inspection["validation_episode"] or inspection["disposition"] != "RETAIN": continue
        formation = next(d for d in days if d["episode_id"] == inspection["formation_episode"])
        sources = set(formation["state"]["observations"])
        paths = [p for p in sidecar.snapshot()["review_path"]["paths"] if p["F"]["source_observation_id"] in sources
                 and p["F_prime"]["source_observation_id"] in sources and p["E"]["deltas"]["visible_objects_count"] != 0]
        if not paths:
            learning = dict(status="review_difference_unavailable", cutover=None)
            continue
        a = paths[0]
        review = sidecar.review_assessment(dict(assessment_id=a["assessment_id"], expected_revision=0,
            reviewer="l13v-explicit-inspector", basis="actual patch-count Difference; no-food is separately inspected relation evidence",
            evidence=a["F_prime"]["source_observation_id"],
            dimensions={k:dict(status="unresolved", residual=abs(v)) if v else dict(status="zero") for k,v in a["E"]["deltas"].items()}))
        experiences = [deepcopy(d["experience"]) for d in days[:index]
                       if d["episode_id"] in (inspection["formation_episode"], inspection["validation_episode"])]
        require(len(experiences) == 2, "independent_experiences_required")
        bundle = sidecar.expand_t1_materials(assessment_id=review["assessment_id"], candidates=[candidate], experiences=experiences)
        require(bundle is not None, "T1_capacity")
        selections = [dict(material_id=m["material_id"], disposition="RETAIN" if m["kind"] in ("current_M_B", "CandidateRelation") else "DEFER",
            basis="one formation and one independent complete survey; finite no-discovery scope", evidence=digest(inspection)) for m in bundle["materials"]]
        selection = sidecar.inspect_t1_materials(bundle_id=bundle["bundle_id"], payload=dict(expected_revision=0, reviewer="l13v-explicit-inspector", materials=selections))
        artifact = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
        require(selection is not None and artifact is not None, "T1_capacity")
        cutover = sidecar.cutover_reentry(artifact_id=artifact["artifact_id"], expected_active_model_ref=artifact["parent_model_ref"],
            operator="l13v-explicit-Sleep-boundary", basis="activate inspected finite no-discovery relation", evidence=digest(inspection)) if activate else None
        require(not activate or cutover is not None, "cutover_capacity")
        learning = dict(status="reconstructed", review=review, bundle=bundle, selection=selection, artifact=artifact, cutover=cutover)
    return sidecar, learning


class NeighborhoodExplorationSeries(LearnedExplorationSeries):
    day_type = NeighborhoodExplorationDay
    candidate_builder = staticmethod(make_candidate)
    candidate_inspector = staticmethod(inspect_day)
    canonical_builder = staticmethod(canonical_state)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.config["schema"] = NEIGHBORHOOD_SCHEMA

    def sleep_status(self, state, candidate):
        if self.config["mode"] == "record": return "record_only"
        if state["probe"]: return "inspected"
        if candidate and candidate["common_relation_signature"]["kind"] == RELATION: return "tentative_no_discovery"
        return "tentative_route" if candidate else "no_eligible_completed_search"

    def next_day_model(self):
        # No complete section means no canonical count interpretation or Difference.
        # The day controller can still use its unlearned diagnostic model to wait.
        return super().next_day_model() if self.canonical.snapshot()["models"] else None

    def start_revisit_day(self, request, sampling_seed):
        """Explicit paired experiment: repeat the formation sampler, never a World path oracle."""
        integer(sampling_seed, 0, 2**32-1)
        with self.lock:
            require(self.inspection is not None, "revisit_requires_inspection")
            require(self.pending is None or "revisit_seed" in self.pending, "revisit_binding")
            start = self.start_day(request)
            if "revisit_seed" in start:
                require(start["revisit_seed"] == sampling_seed, "revisit_conflict")
                return start
            require(self.loop.config is None and self.pending is not None, "revisit_already_started")
            self.loop.seed = sampling_seed
            self.pending.update(seed=sampling_seed, revisit_seed=sampling_seed)
            return deepcopy(self.pending)
