"""L14A: continuous finite harvesting, sourced material teaching, no learned tree value.

This is the resource/body prerequisite of the long-term learning plan. The
existing appearance servo and survey are initial control, not adopted M_B.
"""
from copy import deepcopy
from math import atan2, degrees
from types import SimpleNamespace

from .exploration import FiniteExploration, RESOURCE_SCHEMA, fields, require, integer, ref
from .exploration_series import digest
from .landmark_exploration import LandmarkExplorationDay, initial_state
from .neighborhood_exploration import NeighborhoodExplorationDay, local_state, descriptor, SURVEY
from .learned_exploration import observation_key

PERIOD_US = 16_000_000
TEACHING_PREDICATE = "food_after_known_processing"


class ResourceExploration(FiniteExploration):
    period_us = PERIOD_US
    allow_resources = True
    inventory_capacity = 32
    max_periods = 30

    def __init__(self, run_id, periods=30, seed=20260928, agent_id="npc_a"):
        integer(periods, 1, self.max_periods); integer(seed, 0, 2**32-1)
        self.periods, self.seed = periods, seed
        self.capacity, self.limit_us = periods*(self.period_us//250_000), periods*self.period_us
        self.deadline_us = self.limit_us+9_000_000
        super().__init__(run_id, agent_id)
        self.teaching = None
        self.decisions = {}

    def carried_count(self):
        # Legacy paths retain cumulative accounting unless explicitly specialized.
        return sum(r["acquired"] for r in self.results.values())

    def expiry(self, capture_us):
        return min(super().expiry(capture_us), (capture_us//self.period_us+1)*self.period_us)

    def configure(self, value):
        with self.lock:
            fields(value, "schema run_id world_epoch agent_id clock_id teaching")
            require(value["schema"] == RESOURCE_SCHEMA, "resource_configuration_required")
            t = value["teaching"]
            fields(t, "statement_id source sample_observation appearance predicate")
            for k in ("statement_id", "sample_observation"): ref(t[k])
            require(t["source"] == "god_statue" and t["predicate"] == TEACHING_PREDICATE, "teaching_source")
            require(t["appearance"] == "brown_capped_ovoid", "sample_appearance")
            require(self.teaching is None or self.teaching == t, "teaching_conflict")
            response = super().configure({k:deepcopy(v) for k,v in value.items() if k != "teaching"})
            self.teaching = deepcopy(t)
            return dict(response, teaching=deepcopy(t))

    def _decision(self, p):
        period = p["capture_us"]//self.period_us
        last = next(reversed(self.decisions.values())) if self.decisions else None
        same = last is not None and last["period"] == period
        landmark = deepcopy(last["landmark"]) if same else initial_state()
        neighborhood = deepcopy(last["neighborhood"]) if same else local_state()
        approach = deepcopy(last["approach"]) if same else None
        blocked = list(last["blocked_targets"]) if same else []
        previous = next(reversed(self.observations.values())) if self.observations else None
        result = self.results.get("op:"+previous["observation_id"]) if previous else None
        action, target, reason = ["wait", 0], "", "acquisition_incomplete"
        body_ok = previous is None or (result is not None and result["after_pose_ref"] == p["pose_ref"]
            and result["after_revision"] == p["body_revision"] and result["executed_us"] < p["capture_us"])
        if self.carried_count() >= self.inventory_capacity:
            reason = "inventory_capacity"
        elif not body_ok:
            reason = "body_correspondence_unavailable"
        elif observation_key(p) is not None:
            if approach and result and last["reason"].startswith("observed_material_"):
                approach["operations"] += 1
                if result["status"] == "blocked" or approach["operations"] >= 24:
                    if approach["ref"] not in blocked: blocked.append(approach["ref"])
                    approach = None
            require(len(blocked) <= 32, "approach_capacity")
            items = [i for i in p["food"]["visible"] if i["appearance"] == self.teaching["appearance"] and i["ref"] not in blocked]
            if items:
                item = items[0]
                if approach is None or approach["ref"] != item["ref"]:
                    approach = dict(ref=item["ref"], operations=0, teaching_ref=self.teaching["statement_id"])
                landmark.update(stage="terminated", outcome="observed_material_priority")
                neighborhood = local_state()
                angle = degrees(atan2(item["right"], item["forward"]))
                if item["distance"] <= 1.25:
                    action, target, reason = ["pickup", 0], item["ref"], "observed_material_in_reach"
                elif abs(angle) > 5:
                    turn = max(-90, min(90, int(round(angle/5))*5))
                    action, reason = ["turn", turn], "observed_material_heading"
                else:
                    action, reason = ["move", 1], "observed_material_approach"
            else:
                approach = None
                # Views contain accepted body/sensor history only. Period renews
                # control budgets, never World stock, position, or a value prior.
                view = SimpleNamespace(observations=self.observations, results=self.results,
                    decisions={"last":dict(landmark=landmark)} if same else {},
                    seed=int(digest([self.seed, period, "neutral-observed-subgoal"] )[:8],16))
                if neighborhood["phase"] == "survey":
                    survey_packet = dict(p, food=dict(p["food"], visible=[i for i in p["food"]["visible"]
                        if i["appearance"] == self.teaching["appearance"]]))
                    action, neighborhood = NeighborhoodExplorationDay._survey(view, survey_packet, neighborhood, landmark)
                else:
                    action, landmark = LandmarkExplorationDay._subgoal(view, p)
                    neighborhood = local_state()
                    if landmark["outcome"] == "near_feature_observed":
                        landmark["stage"] = "survey"
                        neighborhood = dict(phase="survey", outcome=None, prediction=None, survey=dict(
                            survey_id=p["observation_id"]+":survey", start_index=len(self.observations),
                            source_observation=p["observation_id"], source_pose=p["pose_ref"], start_us=p["capture_us"],
                            anchor=descriptor(landmark["goal"]["current_feature"]), start_observed=observation_key(p),
                            cursor=0, odometry=[0.,0.,0.,0.], food_seen=False, return_sources=[]))
                        action = list(SURVEY[0])
                reason = ("neighborhood_"+(neighborhood["outcome"] or neighborhood["phase"]) if neighborhood["phase"] != "idle"
                          else "landmark_"+(landmark["outcome"] or landmark["stage"]))
        return dict(period=period, action=action, target=target, reason=reason, landmark=landmark,
                    neighborhood=neighborhood, approach=approach, blocked_targets=blocked,
                    authority="initial-observed-control; no-learned-tree-value", model_ref=None)

    def select(self, p, previous):
        d = self._decision(p)
        return (*d["action"], d["target"], d["reason"])

    def observe(self, p):
        with self.lock:
            require(self.config is not None and self.teaching is not None, "not_configured")
            self._packet(p)
            if p["observation_id"] in self.observations: return super().observe(p)
            d = self._decision(p)
            response = super().observe(p)
            self.decisions[p["observation_id"]] = deepcopy(d)
            return response

    def result(self, value):
        with self.lock:
            require(isinstance(value, dict), "fields")
            # Unknown results must not create inventory. Base validation checks
            # all bindings/effects before publication; old receipts stay valid.
            if value.get("operation_id") not in self.results and value.get("acquired") is True:
                require(self.carried_count() < self.inventory_capacity, "inventory_capacity")
            return super().result(value)

    def _snapshot_decisions(self):
        return deepcopy(self.decisions)

    def snapshot(self):
        with self.lock:
            s = super().snapshot()
            inventory = [dict(operation_id=r["operation_id"], target_ref=self.commands[r["source_id"]]["target_ref"],
                              acquired_us=r["executed_us"]) for r in self.results.values() if r["acquired"]]
            s.update(schema=RESOURCE_SCHEMA, authority="initial-observed-control; learning-not-connected",
                     periods=self.periods, seed=self.seed, teaching=deepcopy(self.teaching),
                     decisions=self._snapshot_decisions(), inventory=inventory)
            return s
