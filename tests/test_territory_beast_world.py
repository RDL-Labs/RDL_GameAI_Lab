import copy
import unittest

from runtime.territory_beast_world import (
    TerritoryBeastFixture,
    TerritoryBeastWorld,
    TerritoryBeastWorldError,
)
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def fixture(attack_succeeds=True):
    return TerritoryBeastFixture(
        beast_id="beast_1",
        territory_id="north_grove",
        beast_position=(0.0, 0.0),
        territory_center=(0.0, 0.0),
        territory_radius=10.0,
        attack_distance=2.0,
        attack_succeeds=attack_succeeds,
    )


class TerritoryBeastWorldTests(unittest.TestCase):
    def test_outside_is_neutral_fact_without_danger_label(self):
        world = TerritoryBeastWorld(fixture())
        event = world.resolve(agent_id="npc_a", agent_position=(12, 0), tick=1)
        self.assertEqual(event["event_type"], "outside_territory")
        self.assertEqual(event["beast_response"], "ignore")
        self.assertIsNone(event["outcome"])
        self.assertNotIn("danger", event)
        self.assertNotIn("threat_score", event)

    def test_intrusion_progresses_warning_chase_attack_and_world_injury(self):
        world = TerritoryBeastWorld(fixture())
        warning = world.resolve(agent_id="npc_a", agent_position=(9, 0), tick=1)
        chase = world.resolve(agent_id="npc_a", agent_position=(6, 0), tick=2)
        attack = world.resolve(agent_id="npc_a", agent_position=(1, 0), tick=3)
        self.assertEqual((warning["beast_response"], warning["outcome"]),
                         ("warning", "warning_observed"))
        self.assertEqual((chase["beast_response"], chase["outcome"]), ("chase", "chased"))
        self.assertEqual((attack["beast_response"], attack["outcome"]), ("attack", "injured"))
        self.assertEqual(attack["world_consequence"], {
            "injury_level": "medium", "forced_retreat": True, "incapacitated": False,
        })
        self.assertIn("not-danger-belief", attack["authority"])

    def test_leaving_resets_intrusion_relation(self):
        world = TerritoryBeastWorld(fixture())
        world.resolve(agent_id="npc_a", agent_position=(9, 0), tick=1)
        world.resolve(agent_id="npc_a", agent_position=(6, 0), tick=2)
        outside = world.resolve(agent_id="npc_a", agent_position=(12, 0), tick=3)
        reentry = world.resolve(agent_id="npc_a", agent_position=(9, 0), tick=4)
        self.assertEqual(outside["beast_response"], "ignore")
        self.assertEqual(reentry["beast_response"], "warning")

    def test_agent_relations_are_independent_and_snapshot_is_read_only(self):
        world = TerritoryBeastWorld(fixture())
        world.resolve(agent_id="npc_a", agent_position=(9, 0), tick=1)
        world.resolve(agent_id="npc_a", agent_position=(6, 0), tick=2)
        b_warning = world.resolve(agent_id="npc_b", agent_position=(9, 0), tick=2)
        self.assertEqual(b_warning["beast_response"], "warning")
        before = copy.deepcopy(world.snapshot())
        self.assertEqual(world.snapshot(), before)

    def test_capacity_rejects_without_evicting_existing_relation(self):
        world = TerritoryBeastWorld(fixture(), capacity=1)
        world.resolve(agent_id="npc_a", agent_position=(9, 0), tick=1)
        with self.assertRaisesRegex(TerritoryBeastWorldError, "capacity reached"):
            world.resolve(agent_id="npc_b", agent_position=(9, 0), tick=2)
        snapshot = world.snapshot()
        self.assertEqual([item["agent_id"] for item in snapshot["relations"]], ["npc_a"])
        self.assertEqual(snapshot["capacity_rejections"], 1)

    def test_world_events_do_not_automatically_enter_canonical_path(self):
        canonical = GameAIFrozenComparisonSidecar()
        before = copy.deepcopy(canonical.snapshot())
        world = TerritoryBeastWorld(fixture())
        world.resolve(agent_id="npc_a", agent_position=(9, 0), tick=1)
        world.resolve(agent_id="npc_a", agent_position=(6, 0), tick=2)
        world.resolve(agent_id="npc_a", agent_position=(1, 0), tick=3)
        self.assertEqual(canonical.snapshot(), before)
        self.assertEqual(canonical.snapshot()["M_delta"]["active_count"], 0)


if __name__ == "__main__":
    unittest.main()
