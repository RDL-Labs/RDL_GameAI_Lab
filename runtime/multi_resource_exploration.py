"""L14B: isolated agent histories, shared-World transport and local variation demand."""
from copy import deepcopy
from types import SimpleNamespace
from threading import RLock

from .exploration import RESOURCE_SCHEMA, fields, require
from .resource_exploration import ResourceExploration
from .landmark_exploration import LandmarkExplorationDay, initial_state
from .harvest_predictability import affordance, tendency, build_admission, section, PROFILES

SCHEMA = "l14b-multi-resource-predictability-v1"
AGENTS = ("npc_a", "npc_b", "npc_c")


class PredictableResourceAgent(ResourceExploration):
    inventory_capacity = 96

    def __init__(self, run_id, agent_id, profile, periods=30, seed=20260928):
        require(agent_id in AGENTS and profile in PROFILES, "agent_profile")
        super().__init__(run_id, periods, seed, agent_id)
        self.profile = profile
        self.model = None
        self.learning = dict(records=[], admission=None, comparisons=[], confirmations=0,
                             invalidated=False, novelty_landmark=None)
        self._prospective = None

    def _advance(self, p):
        # Lists are copy-on-append; earlier records are immutable after publication.
        s = dict(self.learning)
        model = self.model
        previous = next(reversed(self.observations.values())) if self.observations else None
        if previous:
            c = self.commands[previous["observation_id"]]
            r = self.results.get(c["operation_id"])
            present = affordance(p)
            linked = (r is not None and r["after_pose_ref"] == p["pose_ref"] and
                      r["after_revision"] == p["body_revision"] and r["executed_us"] < p["capture_us"])
            usable = linked and present is not None and affordance(previous) is True and c["kind"] == "pickup" and r["status"] in ("picked_up", "not_found")
            if usable:
                record = dict(agent_id=self.agent_id, operation_id=c["operation_id"], source=previous["observation_id"],
                    later=p["observation_id"], target_ref=c["target_ref"], acquired=r["acquired"], affordance_persists=present,
                    capture_us=previous["capture_us"], executed_us=r["executed_us"], later_us=p["capture_us"])
                require(len(s["records"]) < self.capacity, "experience_capacity")
                s["records"] = s["records"]+[record]
            prediction = self.decisions[previous["observation_id"]]["harvest_prediction"]
            if prediction is not None and linked and present is not None and r["status"] in ("picked_up", "not_found"):
                require(model is not None and prediction["model_ref"] == model.model_ref, "frozen_model_binding")
                later = model.interpret_harvest_pattern(section(self.run_id, self.agent_id, "after", r["acquired"], present))
                deltas = {k:later["values"][k]-v for k,v in prediction["values"].items()}
                confirmed = not any(deltas.values())
                s["comparisons"] = s["comparisons"]+[dict(operation_id=c["operation_id"], source=previous["observation_id"],
                    later=p["observation_id"], model_ref=model.model_ref, F=prediction, F_prime=later,
                    prediction_difference=deltas, confirmed=confirmed)]
                s["confirmations"] = s["confirmations"]+1 if confirmed else 0
                if not confirmed: s["invalidated"] = True
            else:
                s["confirmations"] = 0  # missing, unexecuted and non-harvest are not confirmations
        if model is None and len(s["records"]) >= 5 and (s["admission"] is None or s["admission"]["status"] == "DEFER"):
            model, s["admission"] = build_admission(self.run_id, self.agent_id, s["records"],
                                                   [*self.observations.values(), p])
        return s, model

    def _decision(self, p):
        s, model = self._prospective
        d = super()._decision(p)
        present = affordance(p)
        evaluation = tendency(self.profile, s["confirmations"])
        started = False
        novelty = deepcopy(s["novelty_landmark"])
        active = novelty is not None and novelty["stage"] in ("active", "scan")
        if (not active and evaluation["request_exploration"] and not s["invalidated"] and present is not None
                and d["reason"] not in ("body_correspondence_unavailable", "inventory_capacity")):
            novelty = initial_state(); active = True; started = True
            s["confirmations"] = 0
        if active:
            view = SimpleNamespace(observations=self.observations, results=self.results,
                decisions={"last":dict(landmark=novelty)}, seed=self.seed)
            action, novelty = LandmarkExplorationDay._subgoal(view, p)
            # One finite goal; subsequent goals need new confirmed predictions.
            d.update(action=action, target="", reason="variation_"+(novelty["outcome"] or novelty["stage"]))
            s["novelty_landmark"] = novelty
        prediction = None
        if model is not None and not s["invalidated"] and d["action"][0] == "pickup":
            value = model.interpret_harvest_pattern(section(self.run_id, self.agent_id, "before", False, present))
            if value["status"] == "known": prediction = value
        d.update(authority="initial observed control + explicitly adopted harvest M_B + local variation demand",
            model_ref=model.model_ref if model else None, harvest_prediction=prediction,
            variation=evaluation, exploration_started=started, novelty_landmark=deepcopy(s["novelty_landmark"]))
        # Same evidence, separate profiles; counts never include another agent.
        confirmations = self._prospective_confirmations
        d["counterfactual"] = {name:tendency(name, confirmations) for name in PROFILES}
        return d

    def observe(self, p):
        with self.lock:
            require(self.config is not None and self.teaching is not None, "not_configured")
            self._packet(p)
            if p["observation_id"] in self.observations:
                # Base replay must not rerun induction, appraisal or sampling.
                return super(ResourceExploration, self).observe(p)
            s, model = self._advance(p)
            self._prospective = (s, model)
            self._prospective_confirmations = s["confirmations"]
            try:
                # Resource.observe calculates twice. _decision mutates only its
                # prospective state, so compute once and reuse the frozen choice.
                d = self._decision(p)
                self._cached_choice = d
                response = super(ResourceExploration, self).observe(p)
            finally:
                self._prospective = None
                self._cached_choice = None
            self.decisions[p["observation_id"]] = deepcopy(d)
            self.learning, self.model = s, model
            return response

    def select(self, p, previous):
        d = self._cached_choice
        return (*d["action"], d["target"], d["reason"])

    def snapshot(self):
        with self.lock:
            s = super().snapshot()
            s.update(schema=SCHEMA, authority="explicit individual M_B and local predictability appraisal",
                profile=self.profile, learning=deepcopy(self.learning), active_model=self.model.to_json() if self.model else None)
            return s


class MultiResourceExploration:
    schema = SCHEMA
    agent_type = PredictableResourceAgent

    def __init__(self, run_id, periods=30, seed=20260928, assignment="mixed"):
        require(assignment in ("mixed", "swapped", "steady"), "assignment")
        profiles = ("steady", "curious", "restless") if assignment == "mixed" else (
            ("restless", "curious", "steady") if assignment == "swapped" else ("steady",)*3)
        self.run_id, self.periods, self.seed, self.assignment = run_id, periods, seed, assignment
        self.lock = RLock()
        self.agents = {a:self.agent_type(run_id, a, t, periods, seed) for a,t in zip(AGENTS, profiles)}

    def dispatch(self, name, value):
        with self.lock:
            require(isinstance(value, dict) and value.get("agent_id") in self.agents, "unknown_agent")
            a = self.agents[value["agent_id"]]
            prefix = self.run_id+":"+a.agent_id+":"
            for k in ("observation_id", "source_id", "pose_ref", "before_pose_ref", "after_pose_ref"):
                if k in value: require(isinstance(value[k], str) and value[k].startswith(prefix), "cross_agent_reference")
            if "operation_id" in value:
                require(isinstance(value["operation_id"], str) and value["operation_id"].startswith("op:"+prefix), "cross_agent_operation")
            if name == "observe":
                frame = value.get("distant")
                require(isinstance(frame, dict) and isinstance(frame.get("frame_id"), str)
                        and frame["frame_id"].startswith(prefix), "cross_agent_frame")
            if name == "configure":
                fields(value, "schema run_id world_epoch agent_id clock_id teaching selection_profile")
                require(value["schema"] == self.schema and value["selection_profile"] == a.profile, "configuration")
                v = {k:deepcopy(v) for k,v in value.items() if k != "selection_profile"}
                v["schema"] = RESOURCE_SCHEMA
                return a.configure(v)
            return getattr(a, name)(value)

    def configure(self,v): return self.dispatch("configure",v)
    def observe(self,v): return self.dispatch("observe",v)
    def result(self,v): return self.dispatch("result",v)
    def finish(self,v): return self.dispatch("finish",v)

    def snapshot(self):
        with self.lock:
            return dict(schema=self.schema, run_id=self.run_id, periods=self.periods, seed=self.seed,
                assignment=self.assignment, agents={a:v.snapshot() for a,v in self.agents.items()})
