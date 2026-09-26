import json
import unittest

from runtime.life_policy import BaseFoodLifePolicy


def risky_packet():
    return {
        "schema_version": "rdl-luanti-observation-v1",
        "observation_id": "luanti-l4-0",
        "tick": 0,
        "agent_id": "npc_a",
        "observation": {
            "visible_agents": [],
            "visible_objects": [
                {
                    "id": "tasty_food", "kind": "food",
                    "desirability_fixture": "HIGH", "territory_id": "north_grove",
                    "within_reach": False,
                },
                {"id": "beast_1", "kind": "beast"},
            ],
            "visible_places": [{"id": "base", "within_reach": True}],
            "visible_regions": [{
                "id": "north_grove", "relation": "contains",
                "object_id": "tasty_food", "distance_band": "visible",
            }],
            "external_statements": [{
                "statement_id": "god-statue-tasty-food-v1",
                "schema": "external-value-statement-v1",
                "source_type": "external_statement",
                "source_id": "god_statue",
                "subject_id": "tasty_food",
                "predicate": "tasty",
                "polarity": "positive",
                "value_band": "HIGH",
                "authority": "source-attributed-information; not-World-Truth-M_B-H-or-action",
            }],
            "body": {
                "agent_id": "npc_a", "snapshot_id": "luanti-l4-body-0",
                "revision": 0, "movement_scale": 1.0, "injury_level": "none",
                "incapacitated": False, "carried_agent_id": "",
                "last_rescue_delivery": {}, "recovery_stage": "none",
                "recovery_steps": 0, "recovery_place_id": "",
                "food_actions_enabled": True, "food_need": 0.8, "held_food_ids": [],
            },
            "life_context": {
                "god_statue_cue": {
                    "cue_id": "luanti-morning-base-food-low-1",
                    "source": "system_assessment", "topic": "base_food",
                    "band": "low", "delivery": "morning",
                },
                "observed_base_food_band": "low",
                "known_base": {"id": "base"}, "at_base": True,
                "interrupt_candidates": [],
            },
        },
    }


class LuantiL4ContractTests(unittest.TestCase):
    def test_existing_policy_targets_tasty_food_without_danger_label(self):
        packet = risky_packet()
        response = BaseFoodLifePolicy().decide(packet)
        self.assertEqual(response["action"], {"type": "approach", "target_id": "tasty_food"})
        encoded = json.dumps(packet, sort_keys=True).lower()
        for forbidden in ("danger", "dangerous", "threat_score"):
            self.assertNotIn(forbidden, encoded)

    def test_god_statue_statement_is_sourced_information(self):
        statement = risky_packet()["observation"]["external_statements"][0]
        self.assertEqual(
            (statement["source_id"], statement["subject_id"], statement["predicate"]),
            ("god_statue", "tasty_food", "tasty"),
        )
        self.assertIn("not-World-Truth", statement["authority"])


if __name__ == "__main__":
    unittest.main()
