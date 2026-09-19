"""Finite Food -> Rest -> Food coordinator for continuous-life v1."""

from copy import deepcopy

from .core import ObservationError
from .life_policy import BaseFoodLifePolicy
from .rest_policy import RestTrajectoryPolicy


POLICY_ID = "food-rest-continuous-life-v1"
REST_PREEMPT_THRESHOLD = 0.85


class FoodRestCoordinator:
    """Temporarily prefer urgent Rest while retaining the Food trajectory."""

    def __init__(self, food_policy=None, rest_policy=None, capacity=128):
        self.food = food_policy or BaseFoodLifePolicy()
        self.rest = rest_policy or RestTrajectoryPolicy()
        self.capacity = capacity
        self._modes = {}
        self._decisions = {}

    def decide(self, packet):
        agent_id = packet.get("agent_id")
        observation_id = packet.get("observation_id")
        body = packet.get("observation", {}).get("body", {})
        if body.get("food_rest_integration_enabled") is not True:
            raise ObservationError("Food-Rest coordinator requires explicit integration state")
        key = (agent_id, observation_id)
        if key in self._decisions:
            original, response = self._decisions[key]
            if original != packet:
                raise ObservationError("Food-Rest observation ID reused with different contents")
            return deepcopy(response)
        if len(self._decisions) >= self.capacity:
            raise ObservationError("Food-Rest coordinator capacity reached")

        mode = self._modes.get(agent_id, "FOOD")
        food_before = self.food.snapshot()["trajectories"].get(agent_id)
        rest_preempts = body.get("rest_need", 0.0) >= REST_PREEMPT_THRESHOLD
        if mode == "REST" or rest_preempts:
            self._modes[agent_id] = "REST"
            response = self.rest.decide(packet)
            rest_phase = response["inspection"]["rest"]["trajectory_phase"]
            if rest_phase in {"COMPLETE", "RELEASED"}:
                self._modes[agent_id] = "FOOD"
                resumed = self.food.decide(packet)
                food_after = self.food.snapshot()["trajectories"].get(agent_id)
                phase = "RESUME" if food_after is not None else "RELEASE"
                response = resumed
                response["inspection"]["food_rest"] = self._inspection(
                    phase, body, food_before, rest_phase
                )
            else:
                response["inspection"]["food_rest"] = self._inspection(
                    "FOOD_SUSPENDED", body, food_before, rest_phase
                )
        else:
            response = self.food.decide(packet)
            response["inspection"]["food_rest"] = self._inspection(
                "FOOD_ACTIVE", body, food_before, "NONE"
            )
        self._decisions[key] = (deepcopy(packet), deepcopy(response))
        return response

    def record_result(self, payload):
        return self.food.record_result(payload)

    def snapshot(self):
        return {
            "policy": POLICY_ID,
            "modes": deepcopy(self._modes),
            "food": self.food.snapshot(),
            "rest": self.rest.snapshot(),
            "decisions": len(self._decisions),
        }

    @staticmethod
    def _inspection(phase, body, food_before, rest_phase):
        return {
            "policy": POLICY_ID,
            "phase": phase,
            "rest_need": body.get("rest_need"),
            "rest_preempt_threshold": REST_PREEMPT_THRESHOLD,
            "food_before_rest": deepcopy(food_before),
            "rest_phase": rest_phase,
            "rule": "rest_need>=0.85 temporarily preempts Food; completion re-evaluates Food",
            "authority": "GameAI-local-coordinator; not-general-arbitration-M_B-H-or-T1",
        }
