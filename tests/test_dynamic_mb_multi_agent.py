import copy
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.functions.deep_similarity import build_deep_similarity_shadow
from runtime.functions.experience_profile import build_relation_profiles
from runtime.sleep_window import SleepExperienceWindowStore
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result


def canonical_packet(agent_id, source, tick, objects):
    return {
        "observation_id": source,
        "tick": tick,
        "agent_id": agent_id,
        "observation": {
            "perception_rule": "dmb-multi-agent-radius",
            "visible_agents": [],
            "visible_objects": [{"id": f"obj-{index}"} for index in range(objects)],
            "visible_places": [],
        },
    }


def candidates_and_history(agent_ids):
    history = InteractionHistory()
    windows = SleepExperienceWindowStore()
    candidates = {}
    for agent_index, agent_id in enumerate(agent_ids):
        for cycle in range(3):
            source = f"dmbc-{agent_id}-experience-{cycle}"
            observed = food_packet(source, agent=agent_id)
            history.register_decision(observed, decide_action(observed))
            history.record_result(result(source, agent=agent_id))
        window = windows.form_window(
            history.snapshot(), agent_id=agent_id,
            sleep_cycle=f"dmbc-night-{agent_id}", formation_tick=10 + agent_index,
            enabled=True,
        )
        profiles = build_relation_profiles(window, history.snapshot())
        candidates[agent_id] = build_deep_similarity_shadow(
            window, profiles, formation_tick=20 + agent_index
        )["candidate"]
    return history.snapshot(), candidates


class DynamicMBMultiAgentTests(unittest.TestCase):
    def test_two_agents_complete_independent_dynamic_mb_cycles(self):
        agents = ("npc_a", "npc_b")
        history, candidates = candidates_and_history(agents)
        sidecar = GameAIFrozenComparisonSidecar()
        actions_before = {
            agent_id: decide_action(food_packet(f"action-before-{agent_id}", agent=agent_id))
            for agent_id in agents
        }

        assessments = {}
        for index, agent_id in enumerate(agents):
            sidecar.capture(canonical_packet(
                agent_id, f"dmbc-{agent_id}-first", 30 + index * 2, 1
            ))
            sidecar.capture(canonical_packet(
                agent_id, f"dmbc-{agent_id}-later", 31 + index * 2, 3
            ))
        for record in sidecar.snapshot()["assessment"]["records"]:
            assessments[record["E"]["agent_id"]] = record["assessment_id"]

        artifacts = {}
        parent_refs = {}
        for agent_id in agents:
            sidecar.review_assessment({
                "assessment_id": assessments[agent_id], "expected_revision": 0,
                "reviewer": "dmb-c-test", "basis": "independent agent rupture fixture",
                "evidence": f"dmbc-{agent_id}",
                "dimensions": {
                    "visible_agents_count": {"status": "zero"},
                    "visible_objects_count": {"status": "unresolved", "residual": 1.0},
                    "visible_places_count": {"status": "zero"},
                },
            })
            own_experience = [record for record in history["records"]
                              if record["agent_id"] == agent_id]
            bundle = sidecar.expand_t1_materials(
                assessment_id=assessments[agent_id],
                candidates=[candidates[agent_id]], experiences=own_experience,
            )
            sidecar.inspect_t1_materials(
                bundle_id=bundle["bundle_id"],
                payload={
                    "expected_revision": 0,
                    "reviewer": "dmb-c-test",
                    "materials": [{
                        "material_id": item["material_id"],
                        "disposition": ("RETAIN" if item["kind"] in
                                        {"current_M_B", "CandidateRelation", "RIB_B", "RIB_B_prime"}
                                        else "DEFER"),
                        "basis": f"same-agent inspection {agent_id}",
                        "evidence": item["source_id"],
                    } for item in bundle["materials"]],
                },
            )
            artifact = sidecar.reconstruct_t1(bundle_id=bundle["bundle_id"])
            artifacts[agent_id] = artifact
            parent_refs[agent_id] = artifact["parent_model_ref"]

        before_cutover = copy.deepcopy(sidecar.snapshot())
        self.assertEqual(before_cutover["M_delta"]["active_count"], 2)
        self.assertEqual(len(before_cutover["models"]), 2)

        for agent_id in agents:
            artifact = artifacts[agent_id]
            sidecar.cutover_reentry(
                artifact_id=artifact["artifact_id"],
                expected_active_model_ref=artifact["parent_model_ref"],
                operator="dmb-c-test", basis="independent multi-agent cutover",
                evidence=artifact["artifact_id"],
            )

        after = sidecar.snapshot()
        self.assertEqual(after["M_delta"]["active_count"], 0)
        self.assertEqual({state["phase"] for state in after["M_delta"]["states"]}, {"REENTERED"})
        self.assertEqual(set(after["model_archive"]), set(parent_refs.values()))
        self.assertEqual(set(after["models"]), {
            artifacts["npc_a"]["model_ref"], artifacts["npc_b"]["model_ref"],
        })
        for agent_id in agents:
            active = after["models"][artifacts[agent_id]["model_ref"]]
            self.assertEqual(active["agent_id"], agent_id)
            self.assertEqual(
                active["adopted_relations"][0]["source_candidate_id"],
                candidates[agent_id]["candidate_id"],
            )
            self.assertNotEqual(
                candidates[agent_id]["candidate_id"],
                candidates["npc_b" if agent_id == "npc_a" else "npc_a"]["candidate_id"],
            )

        comparisons = after["comparisons"]
        for agent_id in agents:
            self.assertIsNone(sidecar.capture(canonical_packet(
                agent_id, f"dmbc-{agent_id}-reentry-first", 40, 3
            )))
        self.assertEqual(sidecar.snapshot()["comparisons"], comparisons)
        for agent_id in agents:
            mismatch = sidecar.capture(canonical_packet(
                agent_id, f"dmbc-{agent_id}-reentry-later", 41, 4
            ))
            self.assertEqual(mismatch.model_ref, artifacts[agent_id]["model_ref"])

        actions_after = {
            agent_id: decide_action(food_packet(f"action-before-{agent_id}", agent=agent_id))
            for agent_id in agents
        }
        self.assertEqual(actions_after, actions_before)


if __name__ == "__main__":
    unittest.main()
