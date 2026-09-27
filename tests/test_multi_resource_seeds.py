"""Seed panel checks: spatial accounting and unchanged finite World contract."""
from copy import deepcopy
from pathlib import Path
import unittest

from integrations.luanti.tests.analyze_multi_resource_seeds import (
    analyze, load, metrics, occupancy, LATE_START_US,
)


def observation(x, z, us=0, visible=()):
    return dict(body=dict(position=dict(x=x, y=0, z=z)),
                packet=dict(capture_us=us, food=dict(visible=[dict(ref=v) for v in visible])))


def action(x, z, after_x, after_z, us=0):
    return dict(before=dict(position=dict(x=x, y=0, z=z)),
                after=dict(position=dict(x=after_x, y=0, z=after_z)),
                command=dict(capture_us=us, reason="fixture"), result=dict(status="fixture"))


class SpatialAccountingTests(unittest.TestCase):
    def test_floor_bins_keep_negative_coordinates_and_all_samples(self):
        result = occupancy([observation(-0.1, -8.1), observation(-8, -16),
                            observation(0, 0), observation(8, 8)], [])
        self.assertEqual(result["cell_counts"], {"-1,-2": 2, "0,0": 1, "1,1": 1})
        self.assertEqual(result["max_cell_share"], .5)
        self.assertEqual(result["dominant_cells"], ["-1,-2"])

    def test_movement_is_measured_separately_from_spatial_concentration(self):
        result = occupancy([observation(1, 1), observation(2, 1)],
                           [action(1, 1, 2, 1), action(2, 1, 2, 1)])
        self.assertEqual(result["max_cell_share"], 1)
        self.assertEqual(result["distance"], 1)
        self.assertEqual(result["moved_actions"], 1)
        self.assertEqual(result["position_unchanged_actions"], 1)

    def test_empty_measurement_is_not_zero_concentration(self):
        result = occupancy([], [])
        self.assertIsNone(result["max_cell_share"])
        self.assertEqual(result["dominant_cells"], [])
        self.assertEqual(result["samples"], 0)

    def test_capture_boundary_and_observed_vs_harvested_sites(self):
        a = dict(profile="steady", observations=[observation(0, 0, LATE_START_US-1, ["r1"]),
            observation(8, 8, LATE_START_US, ["r2"])],
            actions=[action(0, 0, 0, 0, LATE_START_US-1), action(8, 8, 9, 8, LATE_START_US)],
            inventory=[dict(target_ref="r1", acquired_us=LATE_START_US-1),
                       dict(target_ref="r1", acquired_us=LATE_START_US)])
        t = dict(learning=dict(admission=None, invalidated=False, comparisons=[]), decisions={})
        data = dict(world=dict(run_id="r", stock_initial=[dict(ref="r1"), dict(ref="r2")],
            final_stock=[dict(ref="r1", remaining=10), dict(ref="r2", remaining=12)], agents=dict(npc_a=a)),
            runtime=dict(exploration=dict(seed=1, assignment="mixed", agents=dict(npc_a=t))))
        before = deepcopy(data)
        result = metrics(data)["agents"]["npc_a"]
        self.assertEqual(result["observed_patches"], {"P1": LATE_START_US-1, "P2": LATE_START_US})
        self.assertEqual(result["harvested_by_patch"], {"P1": 2})
        self.assertEqual(result["pickups_by_ten_periods"], [1, 1, 0])
        self.assertEqual(result["late"]["samples"], 1)
        self.assertEqual(result["late"]["distance"], 1)
        self.assertEqual(result["admission_status"], "NOT_EVALUATED")
        self.assertEqual(data, before)


class RealSeedPanelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.panel = load(Path(__file__).parent / "fixtures/luanti_l14b_seed_replay.json.gz")

    def test_all_predeclared_worlds_replay_with_their_own_seed(self):
        from integrations.luanti.tests.check_multi_resource import check
        self.assertEqual([r["data"]["runtime"]["exploration"]["seed"] for r in self.panel["runs"]],
                         [20260929, 20260930, 20261001])
        for r in self.panel["runs"]:
            self.assertEqual(check(r["data"]), r["summary"])

    def test_conditions_and_derived_analysis_match_saved_evidence(self):
        actual = analyze(self.panel)
        expected = load(Path(__file__).parent / "fixtures/luanti_l14b_seed_analysis.json")
        self.assertEqual(actual, expected)
        for r in actual["runs"]:
            self.assertEqual(r["total_pickups"] + sum(r["remaining_by_patch"].values()), 96)
            self.assertEqual(r["agents"]["npc_a"]["exploration_requests"], 0)
            for a in r["agents"].values():
                self.assertEqual(a["whole"]["samples"], 1920)
                self.assertEqual(a["late"]["samples"], 1280)
                self.assertEqual(sum(a["whole"]["cell_counts"].values()), 1920)


if __name__ == "__main__":
    unittest.main()
