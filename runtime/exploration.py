"""L13A: finite observation-driven exploration, without learning/model authority."""
from copy import deepcopy
from math import atan2, degrees, hypot, isfinite
from threading import RLock

from .sensory_observation import SensoryObservationStore, SCHEMA_VERSION

SCHEMA = "l13a-exploration-v1"
NATURAL_SCHEMA = "l13t-natural-exploration-v1"
LANDMARK_SCHEMA = "l13u-landmark-exploration-v1"
NEIGHBORHOOD_SCHEMA = "l13v-neighborhood-exploration-v1"
MULTIFOOD_SCHEMA = "l13w-multi-food-exploration-v1"
RESOURCE_SCHEMA = "l14a-continuous-resource-exploration-v1"
GROUND = "l13a-ground-nine-v1"
SLOT_US = 250_000
LIMIT_US = 16_000_000
CAPACITY = 64
CELLS = ("center", "front1", "front2", "right1", "right2",
         "left1", "left2", "back1", "back2")


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def fields(value, names):
    require(isinstance(value, dict) and set(value) == set(names.split()), "fields")


def integer(value, low=0, high=10**12):
    require(type(value) is int and low <= value <= high, "integer")


def number(value, low, high):
    require(type(value) in (int, float) and isfinite(value) and low <= value <= high, "number")


def ref(value):
    require(isinstance(value, str) and 0 < len(value) <= 128, "reference")


def choose(packet, previous=None):
    """Designer-supplied rule. Only bounded, current observations are consulted."""
    food = packet["food"]["visible"]
    if packet["food"]["coverage"] == "complete" and food:
        item = food[0]
        if item["distance"] <= 1.25:
            return "pickup", 0, item["ref"], "observed_food_in_reach"
        angle = degrees(atan2(item["right"], item["forward"]))
        if abs(angle) > 45:
            return "turn", 90 if angle > 0 else -90, "", "observed_food_direction"
        return "move", 1, "", "observed_food_direction"
    if packet["ground"]["coverage"] != "complete" or packet["food"]["coverage"] != "complete":
        return "wait", 0, "", "acquisition_incomplete"
    if previous and previous["status"] == "blocked":
        return "turn", 90, "", "previous_move_blocked"
    colors = {c["cell_id"]: c["color"] for c in packet["ground"]["cells"]}
    for cell, kind, amount in (("front1", "move", 1), ("right1", "turn", 90),
                               ("left1", "turn", -90), ("back1", "turn", 90)):
        if colors[cell] == "blue":
            return kind, amount, "", "fixed_color_continuation"
    return "move", 1, "", "unmarked_forward_trial"


class FiniteExploration:
    allow_natural = False
    allow_landmarks = False
    allow_neighborhood = False
    allow_multifood = False
    allow_resources = False
    capacity = CAPACITY
    limit_us = LIMIT_US
    deadline_us = 25_000_000

    def expiry(self, capture_us):
        return min(capture_us + 500_000, self.limit_us)

    def landmarks(self):
        return self.config is not None and self.config["schema"] in (LANDMARK_SCHEMA, NEIGHBORHOOD_SCHEMA, MULTIFOOD_SCHEMA, RESOURCE_SCHEMA)

    def natural(self):
        return self.config is not None and self.config["schema"] in (NATURAL_SCHEMA, LANDMARK_SCHEMA, NEIGHBORHOOD_SCHEMA, MULTIFOOD_SCHEMA, RESOURCE_SCHEMA)

    def __init__(self, run_id, agent_id="npc_a"):
        ref(run_id)
        ref(agent_id)
        self.run_id = run_id
        self.agent_id = agent_id
        self.config = None
        self.observations = {}
        self.commands = {}
        self.results = {}
        self.ending = None
        self.store = SensoryObservationStore(self.capacity, {agent_id: ("fixture-distant-enabled", 1)}, run_id)
        self.lock = RLock()

    def context(self, value):
        require(value["run_id"] == self.run_id and value["agent_id"] == self.agent_id
                and type(value["world_epoch"]) is int and value["world_epoch"] == 1, "context")

    def configure(self, value):
        with self.lock:
            fields(value, "schema run_id world_epoch agent_id clock_id")
            self.context(value)
            schemas = ((SCHEMA,) + ((NATURAL_SCHEMA,) if self.allow_natural else ()) +
                       ((LANDMARK_SCHEMA,) if self.allow_landmarks else ()) +
                       ((NEIGHBORHOOD_SCHEMA,) if self.allow_neighborhood else ()) +
                       ((MULTIFOOD_SCHEMA,) if self.allow_multifood else ()) +
                       ((RESOURCE_SCHEMA,) if self.allow_resources else ()))
            require(value["schema"] in schemas
                    and value["clock_id"] == "world-sim-v1", "configuration")
            require(self.config is None or self.config == value, "configuration_conflict")
            self.config = deepcopy(value)
            return {"accepted": True, "config": deepcopy(value)}

    def _packet(self, p):
        fields(p, "run_id world_epoch agent_id clock_id observation_id capture_us sample_seq pose_ref body_revision ground food distant" + (" landmarks" if self.landmarks() else ""))
        self.context(p)
        require(p["clock_id"] == self.config["clock_id"], "clock")
        for k in ("observation_id", "pose_ref"):
            ref(p[k])
        integer(p["capture_us"], 0, self.limit_us - 1)
        integer(p["sample_seq"], 0, self.capacity - 1)
        require(p["sample_seq"] == p["capture_us"] // SLOT_US, "acquisition_slot")
        integer(p["body_revision"], 0, self.capacity)
        g = p["ground"]
        fields(g, "model profile coverage cells")
        require((g["model"], g["profile"]) == (("l13t-local-surface-rays-v1", "l13t-natural-fixed-v1")
                if self.natural() else (GROUND, "l13a-ground-fixed-v1")), "ground_profile")
        require(g["coverage"] in ("complete", "partial"), "ground_coverage")
        require(isinstance(g["cells"], list) and len(g["cells"]) == 9, "ground_budget")
        for cell, key in zip(g["cells"], CELLS):
            fields(cell, "cell_id color status")
            require(cell["cell_id"] == key, "ground_cell_order")
            require(cell["status"] in ("sampled", "unloaded", "occluded", "no_surface"), "ground_status")
            require(cell["color"] in (("green", "brown", "gray", "blue", "unknown")
                    if self.natural() else ("blue", "gray", "unknown")), "ground_color")
            require((cell["color"] == "unknown") == (cell["status"] != "sampled"), "ground_missing")
        require((g["coverage"] == "complete") == all(c["status"] == "sampled" for c in g["cells"]), "ground_completeness")
        food = p["food"]
        fields(food, "coverage visible")
        require(food["coverage"] in ("complete", "partial"), "food_coverage")
        limit = 5 if self.config["schema"] in (MULTIFOOD_SCHEMA, RESOURCE_SCHEMA) else 1
        require(isinstance(food["visible"], list) and len(food["visible"]) <= limit, "food_budget")
        for item in food["visible"]:
            fields(item, ("ref distance forward right up" if self.natural() else "ref distance forward right") +
                   (" appearance" if self.config["schema"] == RESOURCE_SCHEMA else ""))
            if self.config["schema"] == RESOURCE_SCHEMA:
                require(item["appearance"] in ("brown_capped_ovoid", "gray_round"), "material_appearance")
            ref(item["ref"])
            number(item["distance"], 0, 12)
            for k in ("forward", "right"):
                number(item[k], -12, 12)
            if self.natural(): number(item["up"], -12, 12)
            require(abs(hypot(item["forward"], item["right"], item.get("up", 0)) - item["distance"]) < 0.001, "food_geometry")
        if self.config["schema"] in (MULTIFOOD_SCHEMA, RESOURCE_SCHEMA):
            require(len({i["ref"] for i in food["visible"]}) == len(food["visible"]), "duplicate_food_ref")
            require(food["visible"] == sorted(food["visible"], key=lambda i: (i["distance"], i["ref"])), "food_order")
        d = p["distant"]
        require(isinstance(d, dict), "distant_frame")
        require(d.get("channel") == "vision_distant" and d.get("sensor_id") == "eye"
                and d.get("sensor_model_revision") == "sampled-surface-v0.2", "distant_model")
        require(d.get("clock_id") == p["clock_id"] and d.get("sample_seq") == p["sample_seq"]
                and d.get("sampled_world_tick") == p["sample_seq"]
                and d.get("observer_frame_ref") == p["pose_ref"]
                and d.get("capture_window") == {"kind": "instant", "start_us": p["capture_us"], "end_us": p["capture_us"]}, "distant_binding")
        if self.landmarks():
            from .landmark_exploration import validate_landmarks
            validate_landmarks(p["landmarks"])

    def _stage_sensory_store(self):
        return deepcopy(self.store)

    def select(self, packet, previous):
        return choose(packet, previous)

    def observe(self, p):
        with self.lock:
            require(self.config is not None, "not_configured")
            self._packet(p)
            ident = p["observation_id"]
            existing = self.observations.get(ident)
            if existing is not None:
                require(existing == p, "observation_conflict")
                return self._receipt(ident, 0)
            require(self.ending is None, "run_closed")
            require(len(self.observations) < self.capacity, "observation_capacity")
            if self.observations:
                last = next(reversed(self.observations.values()))
                require(p["capture_us"] > last["capture_us"] and p["sample_seq"] > last["sample_seq"], "observation_order")
            previous = next(reversed(self.results.values())) if self.results else None
            kind, amount, target, reason = self.select(p, previous)
            command = {k: p[k] for k in ("run_id", "world_epoch", "agent_id", "pose_ref", "body_revision", "capture_us")}
            command.update(operation_id="op:" + ident, source_id=ident,
                           expires_us=self.expiry(p["capture_us"]),
                           kind=kind, amount=amount, target_ref=target, reason=reason)
            ref(command["operation_id"])
            # Validate/admit on a copy; no partial publication of ground or distant data.
            staged = self._stage_sensory_store()
            ext = dict(schema_version=SCHEMA_VERSION, run_id=self.run_id, world_epoch=1,
                       agent_id=self.agent_id, delivery_observation_id=ident,
                       delivery_world_tick=p["sample_seq"], delivery_time_us=p["capture_us"], frames=[p["distant"]])
            receipt = staged.admit(dict(agent_id=self.agent_id, observation_id=ident, tick=p["sample_seq"]), ext)
            require(receipt["new_frames"] == 1, "distant_frame_reused_for_new_observation")
            self.store = staged
            self.observations[ident] = deepcopy(p)
            self.commands[ident] = command
            return self._receipt(ident, 1)

    def _receipt(self, ident, count):
        return {"accepted": True, "observation_id": ident, "new_observations": count,
                "new_frames": count, "command": deepcopy(self.commands[ident])}

    def result_contract(self, command):
        """Default discrete-body contract; opt-in bodies may specialize it."""
        return ({"move": {"moved", "blocked"}, "turn": {"turned"},
                 "pickup": {"picked_up", "not_found"}, "wait": {"waited"}}, 1)

    def result(self, value):
        with self.lock:
            require(self.config is not None, "not_configured")
            fields(value, "run_id world_epoch agent_id operation_id source_id executed_us before_pose_ref after_pose_ref before_revision after_revision status forward right yaw acquired" + (" up" if self.natural() else ""))
            self.context(value)
            ident = value["operation_id"]
            ref(ident)
            if ident in self.results:
                require(self.results[ident] == value, "result_conflict")
                return {"accepted": True, "new_result": False}
            require(self.ending is None, "run_closed")
            command = self.commands.get(value["source_id"])
            require(command is not None and command["operation_id"] == ident, "unknown_operation")
            integer(value["executed_us"], command["capture_us"], self.deadline_us)
            for k in ("before_revision", "after_revision"):
                integer(value[k], 0, self.capacity)
            for k in ("before_pose_ref", "after_pose_ref"):
                ref(value[k])
            for k, lo, hi in (("forward", -1.001, 1.001), ("right", -0.001, 0.001), ("yaw", -90.01, 90.01)):
                number(value[k], lo, hi)
            require(type(value["acquired"]) is bool, "acquired")
            status = value["status"]
            if self.natural():
                number(value["up"], -1.001, 1.001)
                require(abs(value["up"] - round(value["up"])) < .001, "vertical_step")
                require(status == "moved" or abs(value["up"]) < .001, "vertical_effect")
            allowed, moved_distance = self.result_contract(command)
            require(status in allowed[command["kind"]] | {"expired", "stale", "stopped"}, "result_status")
            active = status not in ("expired", "stale", "stopped")
            if active:
                require(value["executed_us"] < command["expires_us"]
                        and value["before_revision"] == command["body_revision"]
                        and value["before_pose_ref"] == command["pose_ref"], "execution_binding")
            if status == "expired":
                require(value["executed_us"] >= command["expires_us"], "not_expired")
            if status == "stale":
                require(value["before_revision"] != command["body_revision"] or value["before_pose_ref"] != command["pose_ref"], "not_stale")
            if status == "stopped":
                require(value["executed_us"] >= self.limit_us or (not self.allow_resources and any(r["acquired"] for r in self.results.values())), "not_stopped")
            changed = status in ("moved", "turned", "picked_up")
            require(value["after_revision"] == value["before_revision"] + int(changed), "revision_change")
            require((value["before_pose_ref"] != value["after_pose_ref"]) == changed, "pose_change")
            require(value["acquired"] == (status == "picked_up"), "acquisition_result")
            require(abs(value["forward"] - (moved_distance if status == "moved" else 0)) < 0.001
                    and abs(value["yaw"] - (command["amount"] if status == "turned" else 0)) < 0.01, "measured_effect")
            require(self.allow_resources or not value["acquired"] or not any(r["acquired"] for r in self.results.values()), "duplicate_pickup")
            self.results[ident] = deepcopy(value)
            return {"accepted": True, "new_result": True}

    def finish(self, value):
        with self.lock:
            require(self.config is not None, "not_configured")
            fields(value, "run_id world_epoch agent_id ended_us reason")
            self.context(value)
            integer(value["ended_us"], 0, self.deadline_us)
            require(value["reason"] in ("acquired", "time_limit", "pending_capacity", "operation_budget") + (("return_target_reached",) if getattr(self,"allow_return_target",False) else ()), "end_reason")
            require(self.ending is None or self.ending == value, "finish_conflict")
            require(len(self.results) == len(self.commands), "unreported_operations")
            acquired = any(r["acquired"] for r in self.results.values())
            require(value["reason"] != "acquired" if self.allow_resources else (value["reason"] == "acquired") == acquired, "end_acquisition")
            if value["reason"] == "time_limit":
                require(value["ended_us"] >= self.limit_us, "early_timeout")
            require(all(r["executed_us"] <= value["ended_us"] or r["status"] in ("expired", "stale", "stopped")
                        for r in self.results.values()), "effect_after_end")
            self.ending = deepcopy(value)
            return {"accepted": True, "ending": deepcopy(value)}

    def snapshot(self):
        with self.lock:
            return deepcopy(dict(schema=SCHEMA, authority="fixed-exploration; no-Experience-T1-or-M_B-update",
                                 config=self.config, observations=self.observations, commands=self.commands,
                                 results=self.results, ending=self.ending, sensory=self.store.snapshot()))
