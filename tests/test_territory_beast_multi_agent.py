import copy
import unittest

from runtime.territory_beast_world import TerritoryBeastFixture, TerritoryBeastWorld
from runtime.territory_experience import TerritoryExperienceStore
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def world():
    return TerritoryBeastWorld(TerritoryBeastFixture(
        beast_id="beast_1", territory_id="north_grove",
        beast_position=(0.0, 0.0), territory_center=(0.0, 0.0),
        territory_radius=10.0, attack_distance=2.0,
    ))


class TerritoryBeastMultiAgentTests(unittest.TestCase):
    def test_three_and_five_agent_combined_evidence(self):
        for count in (3, 5):
            with self.subTest(agent_count=count):
                fixture = world()
                experience = TerritoryExperienceStore()
                canonical = GameAIFrozenComparisonSidecar()
                canonical_before = copy.deepcopy(canonical.snapshot())

                warning_a = fixture.resolve(
                    agent_id="npc_a", agent_position=(9, 0), tick=1
                )
                experience.record_direct(warning_a)
                exit_a = fixture.resolve(
                    agent_id="npc_a", agent_position=(12, 0), tick=2
                )
                experience.record_direct(exit_a)

                warning_b = fixture.resolve(
                    agent_id="npc_b", agent_position=(9, 0), tick=1
                )
                chase_b = fixture.resolve(
                    agent_id="npc_b", agent_position=(6, 0), tick=2
                )
                injury_b = fixture.resolve(
                    agent_id="npc_b", agent_position=(1, 0), tick=3
                )
                for event in (warning_b, chase_b, injury_b):
                    experience.record_direct(event)

                observed_c = experience.record_observed(
                    observer_id="npc_c", event=injury_b, observation_tick=3
                )

                for index in range(3, count):
                    agent_id = f"npc_{chr(ord('a') + index)}"
                    outside = fixture.resolve(
                        agent_id=agent_id, agent_position=(15 + index, 0), tick=1
                    )
                    experience.record_direct(outside)

                records = experience.snapshot()["records"]
                by_agent = {}
                for record in records:
                    by_agent.setdefault(record["agent_id"], []).append(record)
                self.assertEqual(
                    [item["interaction"]["beast_response"] for item in by_agent["npc_a"]],
                    ["warning", "ignore"],
                )
                self.assertEqual(
                    [item["interaction"]["beast_response"] for item in by_agent["npc_b"]],
                    ["warning", "chase", "attack"],
                )
                self.assertEqual(observed_c["perspective"], "bounded_observer")
                self.assertEqual(observed_c["interaction"]["subject_agent_id"], "npc_b")
                self.assertIsNone(observed_c["world_consequence"])
                self.assertEqual(
                    by_agent["npc_b"][-1]["world_consequence"]["injury_level"], "medium"
                )
                self.assertTrue(all("danger" not in record for record in records))
                self.assertTrue(all("not-danger-belief" in record["authority"] for record in records))
                self.assertEqual(canonical.snapshot(), canonical_before)

    def test_replay_is_idempotent_and_capacity_does_not_evict(self):
        fixture = world()
        event = fixture.resolve(agent_id="npc_a", agent_position=(9, 0), tick=1)
        store = TerritoryExperienceStore(capacity=1)
        first = store.record_direct(event)
        self.assertEqual(store.record_direct(event), first)
        self.assertIsNone(store.record_observed(
            observer_id="npc_b", event=event, observation_tick=1
        ))
        snapshot = store.snapshot()
        self.assertEqual(snapshot["records"], [first])
        self.assertEqual(snapshot["capacity_rejections"], 1)


if __name__ == "__main__":
    unittest.main()
