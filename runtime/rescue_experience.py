"""SOC-0 opt-in bounded Rescue experience; no gradient, relation, or policy hook."""
from copy import deepcopy
import hashlib
import json


class RescueExperienceError(ValueError):
    pass


class RescueExperienceStore:
    def __init__(self, run_id, capacity=16):
        if not isinstance(run_id, str) or not run_id or type(capacity) is not int or not 1 <= capacity <= 16:
            raise RescueExperienceError("invalid fixture boundary")
        self.run_id, self.capacity = run_id, capacity
        self._records = {}

    def record(self, event):
        fields = {"schema", "run_id", "event_id", "agent_id", "source_observation_id", "subsequent_observation_id",
                  "tick", "action", "target_id", "participants", "attempt_condition", "result",
                  "world_consequence", "body_consequence", "authority"}
        def require(ok):
            if not ok: raise RescueExperienceError("invalid bounded Rescue event")
        require(isinstance(event, dict) and set(event) == fields)
        require(event["schema"] == "soc0-rescue-experience-v1" and event["run_id"] == self.run_id)
        require(all(isinstance(event[k], str) and 0 < len(event[k]) <= 128 for k in
                    ("event_id", "agent_id", "source_observation_id", "subsequent_observation_id", "target_id")))
        require(event["source_observation_id"] != event["subsequent_observation_id"])
        require(type(event["tick"]) is int and event["tick"] >= 0)
        ps = event["participants"]
        require(isinstance(ps, list) and 1 <= len(ps) <= 3 and all(isinstance(p,str) for p in ps))
        require(len(set(ps)) == len(ps) and event["agent_id"] in ps and event["target_id"] not in ps)
        require(event["attempt_condition"] == ("solo" if len(ps)==1 else "joint"))
        outcome = event["result"]
        require(outcome in ("carry_not_established", "carry_established", "delivered"))
        require(event["action"] == ("deliver" if outcome == "delivered" else "rescue"))
        world, body = event["world_consequence"], event["body_consequence"]
        require(isinstance(world,dict) and set(world)=={"target_moved","carry_established"})
        require(all(type(v) is bool for v in world.values()))
        require(world["carry_established"] == (outcome == "carry_established"))
        require(outcome != "carry_not_established" or not world["target_moved"])
        require(isinstance(body,dict) and set(body)=={"actor_incapacitated","target_incapacitated","target_recovery_stage"})
        require(type(body["actor_incapacitated"]) is bool and type(body["target_incapacitated"]) is bool)
        require(body["target_recovery_stage"] in ("none","stabilizing","mobilizing","recovering","recovered"))
        require(event["authority"] == "bounded-rescue-experience-only; not-social-relation-NERV-T1-or-action")
        key = event["event_id"]
        if key in self._records:
            if self._records[key]["event"] != event: raise RescueExperienceError("event_conflict")
            return deepcopy(self._records[key])
        if len(self._records) >= self.capacity: raise RescueExperienceError("experience_capacity")
        record = {"record_id": hashlib.sha256(json.dumps([self.run_id,key],sort_keys=True).encode()).hexdigest(),
                  "event": deepcopy(event), "authority": "bounded-Experience-only; no-social-learning"}
        self._records[key] = record
        return deepcopy(record)

    def snapshot(self):
        return deepcopy({"run_id":self.run_id,"records":list(self._records.values()),
                         "retention":"finite process-local fixture; no automatic NERV/T1 intake"})
