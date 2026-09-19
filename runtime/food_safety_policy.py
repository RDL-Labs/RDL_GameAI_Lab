"""Finite Food -> Safety -> Food coordinator for continuous-life Phase E."""

from copy import deepcopy

from .core import ObservationError
from .life_policy import BaseFoodLifePolicy
from .safety_policy import SafetyTrajectoryPolicy


POLICY_ID = "food-safety-continuous-life-v1"


class FoodSafetyCoordinator:
    def __init__(self, food_policy=None, safety_policy=None, capacity=128):
        self.food = food_policy or BaseFoodLifePolicy()
        self.safety = safety_policy or SafetyTrajectoryPolicy()
        self.capacity = capacity
        self._modes = {}
        self._decisions = {}

    def decide(self, packet):
        agent_id = packet.get("agent_id")
        observation_id = packet.get("observation_id")
        body = packet.get("observation", {}).get("body", {})
        if body.get("food_safety_integration_enabled") is not True:
            raise ObservationError("Food-Safety coordinator requires explicit integration state")
        key = (agent_id, observation_id)
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("Food-Safety observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("Food-Safety coordinator capacity reached")

        safety = packet["observation"]["safety_context"]
        mode = self._modes.get(agent_id, "FOOD")
        food_before = self.food.snapshot()["trajectories"].get(agent_id)
        if safety["exposed"] or mode == "SAFETY":
            if mode != "SAFETY":
                self._modes[agent_id] = "SAFETY"
            response = self.safety.decide(packet)
            safety_phase = response["inspection"]["safety"]["trajectory_phase"]
            if safety_phase == "COMPLETE":
                self._modes[agent_id] = "FOOD"
                resumed = self.food.decide(packet)
                food_after = self.food.snapshot()["trajectories"].get(agent_id)
                outcome = "RESUME" if food_after is not None else "RELEASE"
                response = resumed
                response["inspection"]["food_safety"] = {
                    "policy": POLICY_ID, "phase": outcome,
                    "food_before_safety": deepcopy(food_before),
                    "safety_phase": "COMPLETE",
                    "authority": "GameAI-local-coordinator; not-general-arbitration-M_B-H-or-T1",
                }
            else:
                response["inspection"]["food_safety"] = {
                    "policy": POLICY_ID, "phase": "FOOD_SUSPENDED",
                    "food_before_safety": deepcopy(food_before),
                    "safety_phase": safety_phase,
                    "authority": "GameAI-local-coordinator; not-general-arbitration-M_B-H-or-T1",
                }
        else:
            response = self.food.decide(packet)
            response["inspection"]["food_safety"] = {
                "policy": POLICY_ID, "phase": "FOOD_ACTIVE",
                "safety_phase": "NONE",
                "authority": "GameAI-local-coordinator; not-general-arbitration-M_B-H-or-T1",
            }
        self._decisions[key] = (deepcopy(packet), deepcopy(response))
        return response

    def record_result(self, payload):
        return self.food.record_result(payload)

    def snapshot(self):
        return {"policy": POLICY_ID, "modes": deepcopy(self._modes),
                "food": self.food.snapshot(), "safety": self.safety.snapshot(),
                "decisions": len(self._decisions)}
