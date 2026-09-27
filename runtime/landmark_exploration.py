"""L13U: observed surface subgoals; no World identity, map or Food prior.

Heading servo and a bounded acquisition scan are initial body/sensor controls.
Food-route learning remains the explicit episodic Sleep/T1/M_B path of L13S.
"""
from copy import deepcopy
from random import Random

from .exploration import LANDMARK_SCHEMA, CAPACITY, fields, require, number, ref
from .exploration_series import digest
from .learned_exploration import LearnedExplorationDay, LearnedExplorationSeries, observation_key

MODEL = "l13u-horizontal-surface-fan-v1"
PROFILE = "l13u-landmark-fixed-v1"
MAX_GOALS, MAX_OPERATIONS, MAX_SCANS = 8, 12, 4


def validate_landmarks(frame):
    fields(frame, "model profile coverage output_limited features")
    require(frame["model"] == MODEL and frame["profile"] == PROFILE, "landmark_profile")
    require(frame["coverage"] in ("complete", "partial") and type(frame["output_limited"]) is bool, "landmark_coverage")
    require(not frame["output_limited"] or frame["coverage"] == "partial", "landmark_limited")
    require(isinstance(frame["features"], list) and len(frame["features"]) <= 13, "landmark_budget")
    seen, end = set(), -90
    for f in frame["features"]:
        fields(f, "ref color azimuth range_band")
        ref(f["ref"]); require(f["ref"] not in seen, "landmark_reference_reused"); seen.add(f["ref"])
        require(f["color"] in ("green", "brown", "gray", "blue", "red"), "landmark_color")
        require(f["range_band"] in ("near", "mid", "far"), "landmark_range")
        require(isinstance(f["azimuth"], list) and len(f["azimuth"]) == 2, "landmark_angle")
        lo, hi = f["azimuth"]
        number(lo, -90, 90); number(hi, -90, 90)
        require(end <= lo < hi, "landmark_angle_order"); end = hi


def center(feature):
    return sum(feature["azimuth"])/2


def compatible(feature, prior, measured_yaw, margin):
    expected = center(prior)-measured_yaw
    return feature["color"] == prior["color"] and abs(center(feature)-expected) <= margin


def initial_state():
    return dict(stage="idle", selected_count=0, scan_count=0, goal=None,
                outcome=None, candidates=[], selection_index=None)


def terminate(state, outcome):
    state.update(stage="terminated", outcome=outcome, selection_index=None)
    return ["wait", 0], state


class LandmarkExplorationDay(LearnedExplorationDay):
    allow_landmarks = True
    configuration_schema = LANDMARK_SCHEMA

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # No random direction/length tape is consumed by this mode.
        self.tape, self.draws = [["wait", 0] for _ in range(CAPACITY)], []

    def configure(self, value):
        require(isinstance(value, dict) and value.get("schema") == self.configuration_schema, "landmark_configuration_required")
        return super().configure(value)

    def _subgoal(self, p):
        last = next(reversed(self.decisions.values())) if self.decisions else None
        state = deepcopy(last["landmark"]) if last else initial_state()
        state.update(candidates=[], selection_index=None, outcome=None)
        features = p["landmarks"]["features"]
        if observation_key(p) is None:
            return terminate(state, "acquisition_incomplete")
        if state["stage"] == "active":
            goal = state["goal"]
            previous = next(reversed(self.observations.values()))
            result = self.results.get("op:"+previous["observation_id"])
            if (result is None or result["after_pose_ref"] != p["pose_ref"] or
                    result["after_revision"] != p["body_revision"] or result["executed_us"] >= p["capture_us"]):
                return terminate(state, "body_correspondence_unavailable")
            if result["status"] == "blocked":
                return terminate(state, "blocked")
            if result["status"] not in ("moved", "turned"):
                return terminate(state, "operation_not_executed")
            goal["operations"] += 1
            # Finite appearance correspondence, not object identity. Translation
            # widens the angular gate; ambiguity never selects an arbitrary winner.
            margin = 30 if result["status"] == "moved" else 15
            matches = [f for f in features if compatible(f, goal["current_feature"], result["yaw"], margin)]
            state["candidates"] = [f["ref"] for f in matches]
            if not matches: return terminate(state, "lost")
            if len(matches) != 1: return terminate(state, "ambiguous")
            f = matches[0]
            goal.update(current_feature=deepcopy(f), current_observation=p["observation_id"], current_pose=p["pose_ref"])
            if f["range_band"] == "near": return terminate(state, "near_feature_observed")
            if goal["operations"] >= MAX_OPERATIONS: return terminate(state, "operation_budget")
        else:
            if state["selected_count"] >= MAX_GOALS:
                state.update(stage="deferred", outcome="goal_budget")
                return ["wait", 0], state
            candidates = [f for f in features if f["range_band"] != "near" and f["azimuth"][1]-f["azimuth"][0] <= 45]
            # Frame refs do not affect choice. The draw selects among currently
            # observed patches, never an unseen direction or destination.
            state["candidates"] = [f["ref"] for f in candidates]
            if not candidates:
                if state["scan_count"] >= MAX_SCANS:
                    state.update(stage="deferred", outcome="no_candidate_after_scan")
                    return ["wait", 0], state
                state.update(stage="scan", goal=None, scan_count=state["scan_count"]+1, outcome="no_candidate")
                return ["turn", 90], state
            seed = int(digest([self.seed, state["selected_count"], "observed-patch-choice-v1"])[:8], 16)
            index = Random(seed).randrange(len(candidates)); f = candidates[index]
            state["selected_count"] += 1
            state.update(stage="active", selection_index=index, goal=dict(
                goal_id=p["observation_id"]+":goal", source_observation=p["observation_id"], source_feature=f["ref"],
                source_pose=p["pose_ref"], source_capture_us=p["capture_us"], operations=0,
                current_feature=deepcopy(f), current_observation=p["observation_id"], current_pose=p["pose_ref"]))
        angle = center(state["goal"]["current_feature"])
        if abs(angle) > 7.5:
            turn = max(-45, min(45, int(round(angle/5))*5))
            return ["turn", turn], state
        return ["move", 1], state

    def _decision(self, p):
        d = super()._decision(p)
        if d["reason"] in ("active_M_B", "validation_probe", "active_M_B_terminal_observation", "validation_probe_terminal_observation"):
            state = initial_state() if not self.decisions else deepcopy(next(reversed(self.decisions.values()))["landmark"])
            state.update(stage="suspended", outcome="episodic_route_authority")
        elif d["reason"] == "observed_food_in_reach":
            state = initial_state() if not self.decisions else deepcopy(next(reversed(self.decisions.values()))["landmark"])
            state.update(stage="terminated", outcome="food_pickup_priority")
        else:
            action, state = self._subgoal(p)
            d.update(action=action, reason="landmark_"+(state["outcome"] or state["stage"]), target="")
        d.update(landmark=state, bootstrap_action=None)
        return d

    def snapshot(self):
        state = super().snapshot()
        state.update(schema=self.configuration_schema, authority="observed-subgoal-or-explicit-validation-Probe-or-active-M_B")
        return state


class LandmarkExplorationSeries(LearnedExplorationSeries):
    day_type = LandmarkExplorationDay

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.config["schema"] = LANDMARK_SCHEMA
