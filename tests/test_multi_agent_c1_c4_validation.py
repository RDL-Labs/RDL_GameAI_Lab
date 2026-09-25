import copy
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.functions.deep_similarity import build_deep_similarity_shadow
from runtime.functions.experience_profile import build_experience_profile, build_relation_profiles
from runtime.functions.fast_retrieval import build_fast_retrieval
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result


def canonical_packet(agent_id, source, tick, objects):
    return {
        "observation_id": source,
        "tick": tick,
        "agent_id": agent_id,
        "observation": {
            "perception_rule": "multi-agent-validation-radius",
            "visible_agents": [],
            "visible_objects": [{"id": f"obj-{index}"} for index in range(objects)],
            "visible_places": [],
        },
    }


class MultiAgentC1C4ValidationTests(unittest.TestCase):
    def test_three_five_and_ten_agents_keep_semantic_boundaries(self):
        for agent_count in (3, 5, 10):
            with self.subTest(agent_count=agent_count):
                agents = [f"npc_{index:02d}" for index in range(agent_count)]
                history = InteractionHistory()
                windows = SleepExperienceWindowStore()
                candidates = {}

                for index, agent_id in enumerate(agents):
                    for cycle in range(3):
                        source = f"r{agent_count}-{agent_id}-{cycle}"
                        observed = food_packet(source, agent=agent_id)
                        history.register_decision(observed, decide_action(observed))
                        history.record_result(result(source, agent=agent_id))
                    window = windows.form_window(
                        history.snapshot(), agent_id=agent_id,
                        sleep_cycle=f"night-{agent_count}-{agent_id}",
                        formation_tick=10 + index, enabled=True,
                    )
                    profiles = build_relation_profiles(window, history.snapshot())
                    candidate = build_deep_similarity_shadow(
                        window, profiles, formation_tick=20 + index
                    )["candidate"]
                    self.assertEqual(candidate["agent_id"], agent_id)
                    candidates[agent_id] = candidate

                records = history.snapshot()["records"]
                self.assertEqual(len(records), agent_count * 3)
                for agent_id in agents:
                    own = [record for record in records if record["agent_id"] == agent_id]
                    current = build_experience_profile(own[-1])
                    sources = [{
                        "source_type": "raw_experience",
                        "source_id": record["record_id"],
                        "profile": build_experience_profile(record),
                    } for record in own[:-1]] + [{
                        "source_type": "sleep_candidate",
                        "source_id": candidates[agent_id]["candidate_id"],
                        "candidate": candidates[agent_id],
                    }]
                    retrieval = build_fast_retrieval(current, sources, query_tick=30)
                    self.assertTrue(all(
                        item["source_provenance"]["agent_id"] == agent_id
                        for item in retrieval["results"]
                    ))

                canonical = GameAIFrozenComparisonSidecar()
                for index, agent_id in enumerate(agents):
                    canonical.capture(canonical_packet(
                        agent_id, f"c{agent_count}-{agent_id}-a", index * 2, 1
                    ))
                    canonical.capture(canonical_packet(
                        agent_id, f"c{agent_count}-{agent_id}-b", index * 2 + 1, 2
                    ))
                pending = canonical.snapshot()
                self.assertEqual(pending["review_path"]["count"], agent_count)
                self.assertEqual(pending["M_delta"]["states"], [])

                for record in pending["assessment"]["records"]:
                    canonical.review_assessment({
                        "assessment_id": record["assessment_id"],
                        "expected_revision": 0,
                        "reviewer": "multi-agent-validation",
                        "basis": "same finite fixture per agent",
                        "evidence": f"agents-{agent_count}",
                        "dimensions": {
                            "visible_agents_count": {"status": "zero"},
                            "visible_objects_count": {"status": "unresolved", "residual": 1.0},
                            "visible_places_count": {"status": "zero"},
                        },
                    })

                final = canonical.snapshot()
                self.assertEqual(final["M_delta"]["active_count"], agent_count)
                self.assertEqual(
                    {path["agent_id"] for path in final["review_path"]["paths"]}, set(agents)
                )
                self.assertEqual(len({
                    path["assessment_id"] for path in final["review_path"]["paths"]
                }), agent_count)
                self.assertEqual(len({
                    path["model_ref"] for path in final["review_path"]["paths"]
                }), agent_count)
                frozen = copy.deepcopy(final)
                self.assertEqual(canonical.snapshot(), frozen)


if __name__ == "__main__":
    unittest.main()
