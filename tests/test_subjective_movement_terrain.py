from copy import deepcopy
from itertools import permutations
import json
from math import isfinite
import unittest

from runtime.subjective_movement_terrain import (
    calculate_terrain, TerrainInputError, SCHEMA, PROFILE, DIRECTIONS,
)


def item(ref="item", forward=5., right=0.):
    return dict(ref=ref, forward=forward, right=right)


def observation(food=(), obstacles=()):
    context = dict(run_id="run", world_epoch=1, agent_id="npc_a", observation_id="obs",
                   clock_id="sim", capture_us=250000, pose_ref="pose", body_revision=4)
    p = dict(schema=SCHEMA, profile=PROFILE, context=context)
    for name, values in (("food", food), ("obstacles", obstacles), ("ground", ())):
        p[name] = dict(source=dict(context, frame_id="frame:"+name), coverage="complete", output_limited=False)
        if name == "ground":
            p[name]["samples"] = [dict(direction_deg=a, status="sampled", height_delta=0.) for a in DIRECTIONS]
        else:
            p[name]["items"] = deepcopy(list(values))
    return p


def values(result, key="total"):
    return [r[key] for r in result["directional_samples"]]


class SubjectiveTerrainTests(unittest.TestCase):
    def test_single_food_valley_points_towards_observed_food(self):
        result = calculate_terrain(observation([item()]))
        self.assertEqual(result["minimum_directions"], [0])
        left, middle_left, center, middle_right, right = values(result)
        self.assertLess(center, middle_left)
        self.assertLess(middle_left, left)
        self.assertEqual(left, right)
        self.assertEqual(middle_left, middle_right)
        self.assertAlmostEqual(center, -8/3)

    def test_food_distance_monotonic_and_bounded(self):
        samples = [values(calculate_terrain(observation([item(forward=d)])), "food")[2]
                   for d in (1., 2., 5., 8., 12.)]
        self.assertEqual(samples, sorted(samples))
        self.assertTrue(all(-4 <= v <= 0 for v in samples))
        self.assertEqual(samples[0], -4)

    def test_mirror_food_and_ground_reflect_entire_numeric_terrain(self):
        left = observation([item(right=-4)])
        left["ground"]["samples"][0]["height_delta"] = .5
        right = deepcopy(left)
        right["food"]["items"][0]["right"] *= -1
        for s in right["ground"]["samples"]:
            s["direction_deg"] *= -1
        a, b = calculate_terrain(left), calculate_terrain(right)
        self.assertEqual(values(a), list(reversed(values(b))))
        self.assertEqual(a["minimum_directions"], [-v for v in reversed(b["minimum_directions"])])

    def test_multiple_food_composes_instead_of_choosing_nearest_or_first(self):
        left, right = item("a", 4, -4), item("b", 4, 4)
        a, b = calculate_terrain(observation([left])), calculate_terrain(observation([right]))
        together = calculate_terrain(observation([left, right]))
        self.assertEqual(a["minimum_directions"], [-45])
        self.assertEqual(b["minimum_directions"], [45])
        self.assertEqual(together["minimum_directions"], [0])
        for x, y, z in zip(values(a), values(b), values(together)):
            self.assertAlmostEqual(z, (x+y)/2)
        self.assertTrue(all(len(r["source_contributions"]["food"]) == 2 for r in together["directional_samples"]))

    def test_food_normalization_and_obstacle_cap_preserve_contributions(self):
        p = observation([item(str(i), 0, 0) for i in range(5)], [item(str(i), 0, 0) for i in range(8)])
        for r in calculate_terrain(p)["directional_samples"]:
            self.assertTrue(-4 <= r["food"] <= 0)
            self.assertEqual(r["obstacle"], 12)
            self.assertEqual(r["source_contributions"]["obstacle_sum"], 48)
            self.assertEqual(len(r["source_contributions"]["obstacles"]), 8)
            self.assertEqual(r["source_contributions"]["food_denominator"], 5)

    def test_obstacle_near_field_monotonic_including_step_past_point(self):
        costs = [values(calculate_terrain(observation(obstacles=[item(forward=d)])), "obstacle")[2]
                 for d in (12, 7, 6, 3, 1.5, 1, .5, 0)]
        self.assertEqual(costs, sorted(costs))
        self.assertEqual(costs[:2], [0, 0])
        self.assertEqual(costs[-3:], [6, 6, 6])
        self.assertTrue(all(isfinite(c) and 0 <= c <= 6 for c in costs))

    def test_food_plus_front_obstacle_leaves_both_symmetric_minima(self):
        result = calculate_terrain(observation([item()], [item("rock", 2, 0)]))
        self.assertEqual(result["minimum_directions"], [-90, 90])
        self.assertNotIn(0, result["minimum_directions"])
        for r in result["directional_samples"]:
            self.assertAlmostEqual(r["total"], r["physical"]+r["food"]+r["obstacle"])
        self.assertNotIn("selected_action", result)
        self.assertNotIn("operation_id", result)

    def test_left_right_obstacle_fields_reflect_not_fixed_right_turn(self):
        a = calculate_terrain(observation([item()], [item("rock", 2, -1)]))
        b = calculate_terrain(observation([item()], [item("rock", 2, 1)]))
        self.assertEqual(values(a), list(reversed(values(b))))
        self.assertTrue(all(v > 0 for v in a["minimum_directions"]))
        self.assertTrue(all(v < 0 for v in b["minimum_directions"]))

    def test_object_and_ground_order_do_not_change_result(self):
        foods = [item("c", 2, -1), item("a", 4, 0), item("b", 7, 3)]
        obstacles = [item("x", 1, -1), item("y", 5, 1)]
        expected = calculate_terrain(observation(foods, obstacles))
        for f in permutations(foods):
            for o in permutations(obstacles):
                p = observation(f, o)
                p["ground"]["samples"].reverse()
                self.assertEqual(calculate_terrain(p), expected)

    def test_renaming_references_only_changes_provenance(self):
        p = observation([item("food-a", 3, -1), item("food-b", 3, 1)], [item("rock", 2, .3)])
        a = calculate_terrain(p)
        for name in ("food", "obstacles", "ground"):
            p[name]["source"]["frame_id"] = "renamed-"+name
            for v in p[name].get("items", []):
                v["ref"] = "renamed-"+v["ref"]
        b = calculate_terrain(p)
        for key in ("physical", "food", "obstacle", "total"):
            self.assertEqual(values(a, key), values(b, key))
        self.assertEqual(a["minimum_directions"], b["minimum_directions"])
        self.assertNotEqual(a["evidence"], b["evidence"])

    def test_partial_or_unavailable_never_becomes_numeric_terrain(self):
        for channel in ("food", "obstacles", "ground"):
            for status in ("partial", "unavailable"):
                with self.subTest(channel=channel, status=status):
                    p = observation()
                    p[channel]["coverage"] = status
                    if status == "unavailable" and channel == "ground":
                        for s in p[channel]["samples"]:
                            s.update(status="unavailable", height_delta=None)
                    result = calculate_terrain(p)
                    self.assertEqual(result["status"], "acquisition_incomplete")
                    self.assertIsNone(result["minimum_directions"])
                    for r in result["directional_samples"]:
                        for key in ("physical", "food", "obstacle", "total", "source_contributions"):
                            self.assertIsNone(r[key])

    def test_partial_known_objects_and_limited_output_keep_reasons_not_scores(self):
        p = observation([item()])
        p["food"].update(coverage="partial", output_limited=True)
        p["obstacles"]["coverage"] = "partial"
        result = calculate_terrain(p)
        self.assertEqual(result["reasons"], ["food_partial", "obstacles_partial", "food_output_limited"])
        self.assertEqual(len(result["evidence"]["food"]["items"]), 1)
        self.assertEqual(values(result), [None]*5)

    def test_complete_empty_scene_is_flat_not_unknown(self):
        result = calculate_terrain(observation())
        self.assertEqual(result["status"], "complete")
        self.assertEqual(values(result), [0]*5)
        self.assertEqual(result["minimum_directions"], list(DIRECTIONS))

    def test_physical_height_cost_and_known_unusable_directions(self):
        p = observation([item()])
        for s, height in zip(p["ground"]["samples"], (0, .5, 1, -.5, -1)):
            s["height_delta"] = height
        self.assertEqual(values(calculate_terrain(p), "physical"), [0, 1, 2, 1, 2])
        p["ground"]["samples"][0].update(status="blocked", height_delta=None)
        p["ground"]["samples"][1].update(status="no_surface", height_delta=None)
        p["ground"]["samples"][2]["height_delta"] = 2
        result = calculate_terrain(p)
        self.assertEqual(values(result)[:3], [None]*3)
        self.assertEqual([r["reasons"] for r in result["directional_samples"][:3]],
                         [["blocked"], ["no_surface"], ["step_height_exceeded"]])
        self.assertEqual(result["status"], "complete")

    def test_all_observed_blocked_is_distinct_from_incomplete_and_has_no_minimum(self):
        p = observation()
        for s in p["ground"]["samples"]:
            s.update(status="blocked", height_delta=None)
        result = calculate_terrain(p)
        self.assertEqual(result["status"], "no_supported_direction")
        self.assertEqual(result["minimum_directions"], [])
        self.assertIsNone(result["minimum_height"])
        json.dumps(result, allow_nan=False)

    def test_binding_rejects_other_agent_run_time_pose_and_revision(self):
        for key, value in dict(agent_id="npc_b", run_id="old", world_epoch=2, clock_id="other",
                               observation_id="old-observation", capture_us=249999,
                               pose_ref="other-pose", body_revision=3).items():
            p = observation([item()])
            p["food"]["source"][key] = value
            p["food"]["coverage"] = "partial"  # Missingness must not mask bad bindings.
            with self.subTest(key=key), self.assertRaisesRegex(TerrainInputError, "source_context_mismatch"):
                calculate_terrain(p)

    def test_bounds_invalid_values_and_hidden_fields_rejected(self):
        bad = []
        for name, n in (("food", 6), ("obstacles", 9)):
            p = observation(); p[name]["items"] = [item(str(i)) for i in range(n)]; bad.append(p)
        for value in (float("nan"), float("inf"), True, "1", -1, 13, 10**1000):
            p = observation([item(forward=value)]); bad.append(p)
        p = observation([item(forward=10, right=10)]); bad.append(p)
        p = observation([item(), item()]); bad.append(p)
        p = observation([item()]); p["food"]["items"][0]["world_position"] = [1, 2, 3]; bad.append(p)
        p = observation(); p["terrain_seed"] = 719; bad.append(p)
        p = observation(); p["profile"] = "unlimited"; bad.append(p)
        p = observation(); p["ground"]["samples"].pop(); bad.append(p)
        p = observation(); p["ground"]["samples"][0]["direction_deg"] = 0; bad.append(p)
        p = observation(); p["ground"]["samples"][0].update(status="unavailable", height_delta=None); bad.append(p)
        p = observation(); p["food"]["output_limited"] = True; bad.append(p)
        p = observation([item()]); p["food"]["coverage"] = "unavailable"; bad.append(p)
        p = observation(); p["context"]["capture_us"] = True; bad.append(p)
        for index, p in enumerate(bad):
            with self.subTest(case=index), self.assertRaises(TerrainInputError):
                calculate_terrain(p)

    def test_purity_repeatability_output_independence_and_finite_json(self):
        p = observation([item()], [item("rock", 2, 0)])
        before = deepcopy(p)
        a, b = calculate_terrain(p), calculate_terrain(p)
        self.assertEqual(a, b)
        self.assertEqual(p, before)
        json.dumps(a, allow_nan=False)
        a["evidence"]["food"]["items"][0]["forward"] = 0
        a["directional_samples"][0]["source_contributions"]["ground"]["status"] = "changed"
        self.assertEqual(p, before)
        self.assertEqual(calculate_terrain(p), b)

    def test_l14a_l14b_actions_state_and_canonical_are_unchanged(self):
        from test_resource_exploration import Session as ResourceSession, material
        from test_landmark_exploration import feature
        from test_multi_resource_exploration import Session as MultiSession
        def trace(with_terrain):
            resource, multi = ResourceSession(), MultiSession()
            outputs = []
            for i in range(12):
                if with_terrain:
                    calculate_terrain(observation([item()], [item("rock", 2, 0)]))
                packet = resource.packet([feature()])
                packet["food"]["visible"] = [material()]
                outputs.append((resource.apply(packet), multi.apply(multi.packet(i != 0))))
            self.assertIsNotNone(multi.loop.model)
            self.assertEqual(multi.loop.learning["admission"]["status"], "ADOPTED")
            return deepcopy((outputs, resource.loop.snapshot(), multi.multi.snapshot()))
        self.assertEqual(trace(False), trace(True))

    def test_schema_does_not_enable_existing_exploration_mode(self):
        from runtime.exploration import FiniteExploration
        loop = FiniteExploration("run", "npc_a")
        with self.assertRaises(ValueError):
            loop.configure(dict(schema=SCHEMA, run_id="run", agent_id="npc_a", world_epoch=1, clock_id="world-sim-v1"))
        self.assertIsNone(loop.config)


if __name__ == "__main__":
    unittest.main()
