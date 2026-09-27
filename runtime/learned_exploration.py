"""L13S: bounded episodic induction, held-out route Probe, T1 and later M_B use.

The sampler knows no colors, destination, World layout or day-based route.
A validation Probe has explicit, separate authority; it is not learned behavior.
"""
from copy import deepcopy
from random import Random
from threading import RLock

from .exploration import FiniteExploration, CAPACITY, LIMIT_US, require, fields, ref, integer
from .exploration_series import digest, day_metrics
from .v23_acquisition import acquire_rib_section
from .v23_interpretation import GameAIFrozenComparisonSidecar, build_diagnostic_frozen_mb

SCHEMA = "l13s-learned-exploration-v1"
RELATION = "l13s-observed-route-v1"
PURPOSE = "reobserve-food-after-finite-observed-route"


def observation_key(p):
    """Finite observed appearance, not identity or position; missing stays missing."""
    d = p["distant"]
    if (p["ground"]["coverage"] != "complete" or p["food"]["coverage"] != "complete"
            or d["coverage"] != "COMPLETE_WITHIN_PLAN" or d["status"] != "SAMPLED" or d["output_limited"]):
        return None
    key = dict(ground=deepcopy(p["ground"]),
                distant_conditions={k: deepcopy(d[k]) for k in
                    ("profile_id", "profile_revision", "sensor_model_revision", "clock_id", "channel", "sensor_id")},
                features=sorted([{k: deepcopy(f[k]) for k in
                    ("color_band", "azimuth_interval_deg", "elevation_interval_deg")} for f in d["payload"]["features"]],
                    key=lambda f: (f["color_band"], f["azimuth_interval_deg"], f["elevation_interval_deg"])))
    if "landmarks" in p:
        frame = p["landmarks"]
        if frame["coverage"] != "complete" or frame["output_limited"]:
            return None
        key["landmarks"] = {k: deepcopy(frame[k]) for k in ("model", "profile")}
        key["landmarks"]["features"] = [{k: deepcopy(f[k]) for k in ("color", "azimuth", "range_band")}
                                       for f in frame["features"]]
    return key


def projection(p, series_id, day):
    """Canonical finite count adapter. Tick is ledger order, not a rewritten capture time."""
    return dict(schema_version="rdl-gameai-observation-v1", observation_id=p["observation_id"],
        agent_id=p["agent_id"], tick=(day-1)*CAPACITY+p["sample_seq"], observation=dict(
            perception_rule="l13s-food-count:"+series_id, visible_agents=[],
            visible_objects=[dict(id=f["ref"]) for f in p["food"]["visible"]], visible_places=[],
            visible_regions=[], recent_events=[], external_statements=[]))


def bootstrap(seed):
    """Uniform relative quarter-turn and uniform 4..16-unit segment; 64 primitive permits."""
    rng = Random(seed)
    tape, draws = [], []
    while len(tape) < CAPACITY:
        quarter, length = rng.randrange(4), rng.randint(4, 16)
        draws.append(dict(start=len(tape), relative_quarters=quarter, length=length))
        turns = [] if quarter == 0 else ([90, 90] if quarter == 2 else [90 if quarter == 1 else -90])
        tape.extend([("turn", x) for x in turns] + [("move", 1)] * length)
    return [list(a) for a in tape[:CAPACITY]], draws


def interpret(model, section):
    fields(section, "series_id agent_id purpose observed")
    require(section["agent_id"] == model.agent_id and section["purpose"] == PURPOSE, "interpretation_boundary")
    matches = [r for r in model.adopted_relations if r["relation"].get("kind") == RELATION
               and r["relation"].get("series_id") == section["series_id"]]
    result = dict(model_ref=model.model_ref, status="unknown", predicts_food=None,
                  source_candidate=None, route=None, reason="unlearned_condition")
    if section["observed"] is None:
        result["reason"] = "acquisition_incomplete"
    elif len(matches) == 1 and matches[0]["relation"]["trace"][0]["observed"] == section["observed"]:
        result.update(status="known", predicts_food=True,
            source_candidate=matches[0]["source_candidate_id"], route=deepcopy(matches[0]["relation"]),
            reason="inspected_episodic_route; not-place-identity-or-guarantee")
    elif matches:
        result["reason"] = "initial_conditions_unmatched_or_ambiguous"
    return result


class LearnedExplorationDay(FiniteExploration):
    allow_natural = True

    def __init__(self, run_id, series_id, day, seed, model=None, probe=None):
        super().__init__(run_id)
        self.series_id, self.day, self.seed = series_id, day, seed
        self.model = model
        self.probe = deepcopy(probe)
        self.tape, self.draws = bootstrap(seed)
        self.decisions = {}

    def _model(self, p):
        return self.model or build_diagnostic_frozen_mb(acquire_rib_section(projection(p, self.series_id, self.day)))

    def _decision(self, p):
        index = len(self.observations)
        kind, amount = self.tape[index]
        model = self._model(p)
        if not self.decisions:
            prediction = model.interpret_exploration(dict(series_id=self.series_id, agent_id="npc_a",
                purpose=PURPOSE, observed=observation_key(p)))
        else:
            prediction = deepcopy(next(iter(self.decisions.values()))["prediction"])
        route = self.probe["common_relation_signature"] if self.probe else prediction["route"]
        basis = "validation_probe" if self.probe else "active_M_B"
        status, reason = "not_requested", "neutral_sample"
        if route:
            trace = route["trace"]
            prior = list(self.decisions.values())
            aborted = any(d["route_status"] == "aborted" for d in prior)
            if aborted:
                status, reason = "aborted", "route_already_aborted"
            elif index <= len(trace):
                expected = trace[index]["observed"] if index < len(trace) else route["terminal_observed"]
                previous = list(self.observations.values())[-1] if index else None
                result = self.results.get("op:"+previous["observation_id"]) if previous else None
                body_ok = not index or (result is not None
                    and result["status"] == trace[index-1]["result_status"]
                    and abs(result.get("up", 0) - trace[index-1].get("result_up", 0)) < .001
                    and result["after_pose_ref"] == p["pose_ref"] and result["after_revision"] == p["body_revision"]
                    and result["executed_us"] < p["capture_us"])
                if observation_key(p) != expected or not body_ok:
                    status, reason = "aborted", "route_conditions_unavailable"
                elif index == len(trace):
                    status, reason = "completed", basis+"_terminal_observation"
                    kind, amount = "wait", 0
                else:
                    status, reason = "following", basis
                    kind, amount = trace[index]["action"]
            else:
                status, reason = "completed", "neutral_sample_after_route"
        if observation_key(p) is None:
            kind, amount, reason = "wait", 0, "acquisition_incomplete"
        target = ""
        # Reach is an existing bodily precondition; this adds no unseen destination or approach policy.
        if not route and p["food"]["coverage"] == "complete" and p["food"]["visible"] and p["food"]["visible"][0]["distance"] <= 1.25:
            kind, amount, target, reason = "pickup", 0, p["food"]["visible"][0]["ref"], "observed_food_in_reach"
        return dict(index=index, bootstrap_action=self.tape[index], action=[kind, amount], target=target,
            reason=reason, route_status=status, route_id=self.probe["candidate_id"] if self.probe else prediction["source_candidate"],
            prediction=prediction)

    def select(self, packet, previous):
        d = self._decision(packet)
        return (*d["action"], d["target"], d["reason"])

    def observe(self, p):
        with self.lock:
            require(self.config is not None, "not_configured")
            self._packet(p)
            if p["observation_id"] in self.observations:
                return super().observe(p)
            require(len(self.observations) < CAPACITY, "observation_capacity")
            d = self._decision(p)  # pure; failed store admission publishes neither decision nor RNG state
            response = super().observe(p)
            self.decisions[p["observation_id"]] = deepcopy(d)
            if self.model is None:
                self.model = self._model(p)
            return response

    def snapshot(self):
        with self.lock:
            state = super().snapshot()
            state.update(schema=SCHEMA, authority="finite-sampling-or-explicit-validation-Probe-or-active-M_B",
                series_id=self.series_id, day=self.day, seed=self.seed, draws=deepcopy(self.draws),
                tape=deepcopy(self.tape), probe=deepcopy(self.probe), decisions=deepcopy(self.decisions),
                model=self.model.to_json() if self.model else None)
            return state


def make_candidate(state, episode, series_id):
    observations = list(state["observations"].values())
    found = next((i for i,p in enumerate(observations) if p["food"]["visible"]), None)
    if found is None or found == 0 or any(observation_key(p) is None for p in observations[:found+1]):
        return None
    trace = []
    for p, after in zip(observations[:found], observations[1:found+1]):
        c = state["commands"][p["observation_id"]]
        r = state["results"].get(c["operation_id"])
        if (r is None or r["status"] not in ("moved", "turned", "blocked", "waited")
            or r["after_pose_ref"] != after["pose_ref"] or r["after_revision"] != after["body_revision"]
            or r["executed_us"] >= after["capture_us"]):
            return None
        trace.append(dict(observed=observation_key(p), action=[c["kind"], c["amount"]],
            result_status=r["status"], source_observation=p["observation_id"], source_operation=c["operation_id"],
            source_capture_us=p["capture_us"], source_pose=p["pose_ref"]))
        if "up" in r:
            trace[-1]["result_up"] = r["up"]
    relation = dict(kind=RELATION, series_id=series_id, purpose=PURPOSE, trace=trace,
        terminal_observed=observation_key(observations[found]), terminal_source=observations[found]["observation_id"],
        formation_episode=episode, formation_run=state["config"]["run_id"], predicts_food=True,
        scope="one experienced observation/action sequence; not universal road value or place identity")
    return dict(candidate_id="l13s-candidate:"+digest(relation)[:24], agent_id="npc_a", support_count=1,
                common_relation_signature=relation)


def inspect_day(candidate, state, episode):
    relation = candidate["common_relation_signature"]
    require(relation["formation_episode"] != episode and relation["formation_run"] != state["config"]["run_id"], "formation_validation_alias")
    decisions = list(state["decisions"].values())
    observations = list(state["observations"].values())
    require(state["probe"] == candidate, "validation_authority")
    require(set(state["observations"]).isdisjoint({s["source_observation"] for s in relation["trace"]} | {relation["terminal_source"]}), "source_alias")
    n = len(relation["trace"])
    disposition, reason = "DEFER", "route_not_completed"
    if any(d["route_status"] == "aborted" for d in decisions):
        reason = "route_conditions_unavailable"
    elif len(decisions) > n and decisions[n]["route_status"] == "completed":
        disposition = "RETAIN" if observations[n]["food"]["visible"] else "REJECT"
        reason = "held_out_food_reobserved" if disposition == "RETAIN" else "complete_terminal_food_not_observed"
    return dict(disposition=disposition, reason=reason, formation_support=1, validation_count=1,
        formation_episode=relation["formation_episode"], validation_episode=episode,
        validation_run=state["config"]["run_id"], validation_sources=[p["observation_id"] for p in observations[:n+1]],
        candidate_id=candidate["candidate_id"])


def canonical_state(series_id, days, candidate, inspection, activate):
    """Rebuild at day boundary, then publish once: no partially visible T1 update."""
    sidecar = GameAIFrozenComparisonSidecar()
    learning = None
    for day_index, day in enumerate(days, 1):
        ps = list(day["state"]["observations"].values())
        selected = [ps[0]] + [p for p in ps[1:] if p["food"]["visible"]][:1]
        for p in selected:
            sidecar.capture(projection(p, series_id, day_index))
        if not inspection or day["episode_id"] != inspection["validation_episode"] or inspection["disposition"] != "RETAIN":
            continue
        source = candidate["common_relation_signature"]["terminal_source"]
        paths = [p for p in sidecar.snapshot()["review_path"]["paths"] if p["F_prime"]["source_observation_id"] == source]
        require(len(paths) == 1, "review_source_unavailable")
        a = paths[0]
        require(a["E"]["deltas"]["visible_objects_count"] == 1, "review_not_actual_discovery")
        review = sidecar.review_assessment(dict(assessment_id=a["assessment_id"], expected_revision=0,
            reviewer="l13s-explicit-inspector", basis="review actual observed Food-count difference; not reward or automatic H",
            evidence=source, dimensions={k:dict(status="unresolved", residual=abs(v)) if v else dict(status="zero") for k,v in a["E"]["deltas"].items()}))
        experiences = [deepcopy(d["experience"])
            for d in days[:day_index] if d["episode_id"] in (inspection["formation_episode"], inspection["validation_episode"])]
        require(len(experiences) == 2, "independent_experiences_required")
        bundle = sidecar.expand_t1_materials(assessment_id=review["assessment_id"], candidates=[candidate], experiences=experiences)
        require(bundle is not None, "T1_capacity")
        selections = [dict(material_id=m["material_id"], disposition="RETAIN" if m["kind"] in ("current_M_B", "CandidateRelation") else "DEFER",
            basis="one-formation-day-and-one-held-out-Probe; episodic-scope-only", evidence=digest(inspection)) for m in bundle["materials"]]
        selection = sidecar.inspect_t1_materials(bundle_id=bundle["bundle_id"], payload=dict(expected_revision=0,
            reviewer="l13s-explicit-inspector", materials=selections))
        artifact = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
        require(selection is not None and artifact is not None, "T1_capacity")
        cutover = sidecar.cutover_reentry(artifact_id=artifact["artifact_id"], expected_active_model_ref=artifact["parent_model_ref"],
            operator="l13s-explicit-day-boundary", basis="enable independently tested episodic route", evidence=digest(inspection)) if activate else None
        require(not activate or cutover is not None, "cutover_capacity")
        learning = dict(review=review, bundle=bundle, selection=selection, artifact=artifact, cutover=cutover)
    return sidecar, learning


class LearnedExplorationSeries:
    day_type = LearnedExplorationDay
    @staticmethod
    def candidate_builder(*args):
        return make_candidate(*args)

    @staticmethod
    def candidate_inspector(*args):
        return inspect_day(*args)

    @staticmethod
    def canonical_builder(*args):
        return canonical_state(*args)

    def sleep_status(self, state, candidate):
        return "record_only" if self.config["mode"] == "record" else ("inspected" if state["probe"] else
                ("tentative_route" if candidate else "no_eligible_discovery_route"))

    def next_day_model(self):
        return self.canonical.model_for_agent("npc_a") if self.days else None

    def __init__(self, series_id, mode="adopt", seed=20260927, max_days=30):
        ref(series_id); require(mode in ("record", "inspect", "adopt"), "mode")
        integer(seed, 0, 2**32-1); integer(max_days, 1, 30)
        self.config = dict(schema=SCHEMA, series_id=series_id, mode=mode, seed=seed, max_days=max_days, discovery_target=3)
        self.days, self.pending, self.loop = [], None, None
        self.candidate, self.inspection, self.learning, self.failure = None, None, None, None
        self.canonical = GameAIFrozenComparisonSidecar()
        self.lock = RLock()

    def summary(self):
        with self.lock:
            found, time, distance, permits = [], 0, 0, 0
            for day in self.days:
                m = day["metrics"]
                if m["first_food_us"] is not None:
                    found.append(dict(day=day["start"]["day"], episode_id=day["episode_id"], run_id=day["run_id"],
                        observation_id=m["first_food_source"], capture_us=m["first_food_us"], acquired=m["acquired"],
                        day_distance=m["distance_to_discovery"], day_permits=m["permits_to_discovery"],
                        cumulative_us=time+m["first_food_us"], cumulative_distance=distance+m["distance_to_discovery"],
                        cumulative_permits=permits+m["permits_to_discovery"]))
                time += m["exploration_us"]; distance += m["distance"]; permits += m["permits"]
            status = "mechanism_error" if self.failure else ("discovery_target_reached" if len(found) >= 3 else
                      ("discovery_target_unmet_at_limit" if len(self.days) >= self.config["max_days"] else "running"))
            return dict(config=deepcopy(self.config), status=status, completed_days=len(self.days), discovery_count=len(found),
                discoveries=found+[None]*(3-len(found)), consumed_exploration_us=time, distance=distance, permits=permits,
                observations=sum(d["metrics"]["observations"] for d in self.days), failure=self.failure,
                inspection=deepcopy(self.inspection), adopted=bool(self.learning and self.learning["cutover"]))

    def start_day(self, request):
        with self.lock:
            fields(request, "episode_id run_id")
            for v in request.values(): ref(v)
            for d in self.days:
                if request["episode_id"] == d["episode_id"]:
                    require(request["run_id"] == d["run_id"], "episode_conflict")
                    return deepcopy(d["start"])
            if self.pending:
                require(request == self.pending["request"], "day_in_progress")
                return deepcopy(self.pending)
            require(self.summary()["status"] == "running", "series_closed")
            require(all(d["run_id"] != request["run_id"] for d in self.days), "run_reused")
            day = len(self.days)+1
            seed = int(digest([self.config["seed"], day, "neutral-sampler-v1"])[:8], 16)
            probe = self.candidate if self.candidate and self.inspection is None else None
            model = self.next_day_model()
            self.loop = self.day_type(request["run_id"], self.config["series_id"], day, seed, model, probe)
            self.pending = dict(request=deepcopy(request), day=day, seed=seed,
                probe_candidate=probe["candidate_id"] if probe else None, model_ref=model.model_ref if model else None,
                history_refs=[d["experience"]["record_id"] for d in self.days])
            return deepcopy(self.pending)

    def close_day(self, request):
        with self.lock:
            fields(request, "episode_id run_id state_digest")
            for d in self.days:
                if d["episode_id"] == request["episode_id"]:
                    require(request == d["close_request"], "day_conflict")
                    return deepcopy(d["receipt"])
            require(self.pending is not None and self.summary()["status"] == "running", "no_active_day")
            require({k:request[k] for k in ("episode_id", "run_id")} == self.pending["request"], "day_binding")
            state = self.loop.snapshot()
            require(not self.days or (state["config"] is not None and
                    state["config"]["schema"] == self.days[0]["state"]["config"]["schema"]), "acquisition_contract_changed")
            require(digest(state) == request["state_digest"], "state_digest")
            require(state["ending"] and state["ending"]["reason"] in ("acquired", "time_limit"), "unfinished_or_mechanism_error")
            require(bool(state["observations"]) and not next(iter(state["observations"].values()))["food"]["visible"], "initial_food_known_or_missing")
            experience = dict(record_id="l13s-experience:"+digest(request)[:24], schema="l13s-exploration-day-v1", agent_id="npc_a",
                episode_id=request["episode_id"], run_id=request["run_id"], state_digest=request["state_digest"],
                observation_refs=list(state["observations"]), operation_refs=list(state["results"]),
                source_clock="world-sim-v1", source_model_ref=state["model"]["model_ref"], support_unit="one completed day")
            candidate, inspection = deepcopy(self.candidate), deepcopy(self.inspection)
            if self.config["mode"] != "record":
                if state["probe"]:
                    inspection = self.candidate_inspector(candidate, state, request["episode_id"])
                elif candidate is None:
                    candidate = self.candidate_builder(state, request["episode_id"], self.config["series_id"])
            sleep = dict(schema="l13s-episodic-sleep-v1", cycle=len(self.days)+1,
                status=self.sleep_status(state, candidate),
                formation_support=1 if candidate else 0, validation_count=1 if inspection else 0,
                candidate_id=candidate["candidate_id"] if candidate else None, inspection=inspection)
            receipt = dict(accepted=True, experience=experience, sleep=sleep, metrics=day_metrics(state))
            day = dict(episode_id=request["episode_id"], run_id=request["run_id"], close_request=deepcopy(request),
                start=deepcopy(self.pending), state=state, experience=experience, metrics=receipt["metrics"], receipt=receipt)
            staged_days = self.days+[day]
            canonical, learning = self.canonical_builder(self.config["series_id"], staged_days, candidate, inspection, self.config["mode"] == "adopt")
            # Atomic publication. The old day remains pending if any staging or T1 step fails.
            self.days, self.candidate, self.inspection = staged_days, candidate, inspection
            self.canonical, self.learning, self.pending = canonical, learning, None
            return deepcopy(receipt)

    def abort(self, reason):
        with self.lock:
            require(reason in ("world_or_transport_error", "replay_error"), "abort_reason")
            require(self.summary()["status"] == "running" or self.failure == reason, "series_closed")
            self.failure = reason

    def snapshot(self):
        with self.lock:
            return deepcopy(dict(summary=self.summary(), days=self.days, pending=self.pending,
                candidate=self.candidate, inspection=self.inspection, learning=self.learning, canonical=self.canonical.snapshot()))
