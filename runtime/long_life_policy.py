"""Finite G2 coordinator for explicit Food-Safety and Sleep life modes."""

from copy import deepcopy

from .core import ObservationError, decide_action
from .food_safety_policy import FoodSafetyCoordinator


POLICY_ID = "food-safety-sleep-long-life-v1"


class FoodSafetySleepCoordinator:
    """Delegate between mutually exclusive Godot-owned life modes."""

    def __init__(self, food_safety=None):
        self.food_safety = food_safety or FoodSafetyCoordinator()
        self._mode_records = []

    def decide(self, packet):
        body = packet.get("observation", {}).get("body", {})
        sleep_enabled = body.get("sleep_actions_enabled") is True
        food_safety_enabled = body.get("food_safety_integration_enabled") is True
        if sleep_enabled == food_safety_enabled:
            raise ObservationError(
                "G2 requires exactly one explicit Food-Safety or Sleep mode"
            )
        mode = "SLEEP" if sleep_enabled else "FOOD_SAFETY"
        response = decide_action(packet) if sleep_enabled else self.food_safety.decide(packet)
        response.setdefault("inspection", {})["long_life"] = {
            "policy": POLICY_ID,
            "mode": mode,
            "authority": "explicit-mode-coordination-only; not-general-arbitration-M_B-H-or-T1",
        }
        self._mode_records.append({
            "agent_id": packet.get("agent_id"),
            "observation_id": packet.get("observation_id"),
            "mode": mode,
        })
        return deepcopy(response)

    def record_result(self, payload):
        return self.food_safety.record_result(payload)

    def snapshot(self):
        return {
            "policy": POLICY_ID,
            "food_safety": self.food_safety.snapshot(),
            "mode_records": deepcopy(self._mode_records),
            "authority": "read-only-explicit-mode-coordination",
        }
