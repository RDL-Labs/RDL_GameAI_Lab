import copy
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import unittest

from runtime.exploration import FiniteExploration, SCHEMA
from runtime.exploration_series import ExplorationSeries, accepted_day
from tests.test_exploration import packet, result


def trace(run, count=1, found=False, acquired=False, partial=False):
    loop = FiniteExploration(run)
    records = []
    def call(kind, value):
        response = getattr(loop, kind)(value)
        records.append(dict(kind=kind, request=copy.deepcopy(value), response=response))
        return response
    call("configure", dict(schema=SCHEMA, run_id=run, world_epoch=1, agent_id="npc_a", clock_id="world-sim-v1"))
    for seq in range(max(count, 2 if found else 1)):
        p = packet(seq, run)
        p.update(observation_id=f"{run}:obs:{seq}", pose_ref=f"{run}:pose:{seq}", body_revision=seq)
        p["distant"].update(frame_id=f"{run}:d:{seq}", observer_frame_ref=p["pose_ref"])
        if partial:
            p["ground"]["coverage"] = "partial"
            p["ground"]["cells"][0].update(color="unknown", status="unloaded")
        if found and seq == 1:
            p["food"]["visible"] = [dict(ref=f"{run}:food", distance=1, forward=1, right=0)]
        command = call("observe", p)["command"]
        status = ("picked_up" if acquired else "not_found") if found and seq == 1 else ("waited" if partial else "moved")
        r = result(command, status)
        if status in ("moved", "picked_up"):
            r["after_pose_ref"] = f"{run}:pose:{seq+1}"
        call("result", r)
        if acquired:
            if status == "picked_up":
                break
    call("finish", dict(run_id=run, world_epoch=1, agent_id="npc_a",
                        ended_us=r["executed_us"] if acquired else 16000000,
                        reason="acquired" if acquired else "time_limit"))
    return records


def close(series, run="run", episode="episode", **kwargs):
    start = series.start_day(dict(episode_id=episode, run_id=run))
    request = dict(episode_id=episode, run_id=run, deliveries=trace(run, **kwargs))
    return start, request, series.close_day(request)


class ExplorationSeriesTests(unittest.TestCase):
    def test_configuration_bounds(self):
        for cap in (0, 31, True, 3.5):
            with self.assertRaises(ValueError):
                ExplorationSeries("series", max_days=cap)
        with self.assertRaises(ValueError):
            ExplorationSeries("series", mode="learned")

    def test_memory_reset_available_material_and_policy_boundary(self):
        for mode, expected in (("memory", 1), ("reset", 0)):
            s = ExplorationSeries("s", mode)
            close(s)
            start = s.start_day(dict(episode_id="next", run_id="fresh"))
            self.assertEqual(len(s.history()), expected)
            self.assertEqual(start["history_observations"], expected)
            self.assertEqual(len(start["history_refs"]), expected)
            self.assertFalse(start["history_consumed_by_policy"])
            self.assertEqual(len(s.snapshot()["days"]), 1)  # experiment archive also retains reset days

    def test_start_replay_conflict_and_no_parallel_days(self):
        s = ExplorationSeries("s")
        req = dict(episode_id="one", run_id="r")
        self.assertEqual(s.start_day(req), s.start_day(req))
        before = s.snapshot()
        with self.assertRaisesRegex(ValueError, "day_in_progress"):
            s.start_day(dict(episode_id="two", run_id="r2"))
        self.assertEqual(before, s.snapshot())

    def test_run_reuse_and_episode_alias_rejected(self):
        s = ExplorationSeries("s")
        start, request, _ = close(s)
        self.assertEqual(start, s.start_day(dict(episode_id="episode", run_id="run")))
        for req in (dict(episode_id="episode", run_id="another"), dict(episode_id="other", run_id="run")):
            with self.assertRaises(ValueError):
                s.start_day(req)

    def test_close_replay_conflict_and_atomic_failure(self):
        s = ExplorationSeries("s")
        _, request, receipt = close(s)
        self.assertEqual(s.close_day(request), receipt)
        before = s.snapshot()
        request["deliveries"][1]["request"]["ground"]["cells"][0]["color"] = "blue"
        with self.assertRaisesRegex(ValueError, "day_conflict"):
            s.close_day(request)
        self.assertEqual(before, s.snapshot())

    def test_cross_day_response_rejected_without_mutation(self):
        s = ExplorationSeries("s")
        _, old, _ = close(s)
        s.start_day(dict(episode_id="next", run_id="fresh"))
        before = s.snapshot()
        bad = dict(episode_id="next", run_id="fresh", deliveries=old["deliveries"])
        with self.assertRaisesRegex(ValueError, "run_binding"):
            s.close_day(bad)
        self.assertEqual(before, s.snapshot())
        # Late receipt for the old day returns its old result without resolving the new reservation.
        s.close_day(old)
        self.assertEqual(before, s.snapshot())

    def test_malformed_or_forged_day_never_publishes(self):
        valid = trace("r")
        variants = []
        bad = copy.deepcopy(valid); bad[1]["response"]["command"]["kind"] = "wait"; variants.append(bad)
        bad = copy.deepcopy(valid); bad[1]["request"]["world_position"] = [1, 2, 3]; variants.append(bad)
        bad = copy.deepcopy(valid); bad[2]["request"]["agent_id"] = "npc_b"; variants.append(bad)
        variants.append(valid[:-1])
        variants.append(valid * 65)
        for bad in variants:
            s = ExplorationSeries("s")
            s.start_day(dict(episode_id="e", run_id="r")); before = s.snapshot()
            with self.assertRaises((ValueError, KeyError)):
                s.close_day(dict(episode_id="e", run_id="r", deliveries=bad))
            self.assertEqual(before, s.snapshot())

    def test_concurrent_same_day_is_one_episode(self):
        s = ExplorationSeries("s")
        s.start_day(dict(episode_id="e", run_id="r"))
        request = dict(episode_id="e", run_id="r", deliveries=trace("r"))
        with ThreadPoolExecutor(4) as pool:
            results = list(pool.map(s.close_day, [request] * 8))
        self.assertTrue(all(r == results[0] for r in results))
        self.assertEqual(s.summary()["completed_days"], 1)

    def test_retransmissions_do_not_add_observations_or_days(self):
        records = trace("r")
        repeat_observation = copy.deepcopy(records[1])
        repeat_observation["response"].update(new_frames=0, new_observations=0)
        repeat_result = copy.deepcopy(records[2])
        repeat_result["response"]["new_result"] = False
        records[-1:-1] = [repeat_observation, repeat_result]
        s = ExplorationSeries("s")
        s.start_day(dict(episode_id="e", run_id="r"))
        request = dict(episode_id="e", run_id="r", deliveries=records)
        s.close_day(request); s.close_day(request)
        self.assertEqual(s.summary()["observations"], 1)
        self.assertEqual(s.summary()["permits"], 1)
        self.assertEqual(s.summary()["completed_days"], 1)

    def test_initial_food_known_is_not_discovery_experiment(self):
        records = trace("r", found=True)
        # Use the second (Food-visible) acquisition as the first admitted packet.
        loop = FiniteExploration("r")
        changed = []
        for d in [records[0], *records[3:]]:
            response = getattr(loop, d["kind"])(d["request"])
            changed.append(dict(kind=d["kind"], request=d["request"], response=response))
        with self.assertRaisesRegex(ValueError, "initial_food_known"):
            accepted_day(changed)

    def test_foreign_runtime_operation_rejected_in_fresh_day(self):
        from tests.test_exploration import setup
        old = trace("old")[2]["request"]
        new, _ = setup("new")
        before = new.snapshot()
        with self.assertRaisesRegex(ValueError, "context"):
            new.result(old)
        self.assertEqual(before, new.snapshot())

    def test_discovery_stops_new_days_without_claiming_pickup(self):
        s = ExplorationSeries("s")
        close(s, found=True, acquired=False)
        summary = s.summary()
        self.assertEqual(summary["status"], "discovered")
        self.assertFalse(summary["acquired"])
        self.assertEqual(summary["discovery_day"], 1)
        self.assertEqual(summary["time_to_discovery_us"], 270000)
        with self.assertRaisesRegex(ValueError, "closed"):
            s.start_day(dict(episode_id="next", run_id="next"))

    def test_acquisition_and_discovery_recorded_separately(self):
        s = ExplorationSeries("s")
        close(s, found=True, acquired=True)
        self.assertTrue(s.summary()["acquired"])
        metrics = s.snapshot()["days"][0]["metrics"]
        self.assertLess(metrics["first_food_us"], metrics["acquired_us"])
        self.assertLess(s.summary()["permits_to_discovery"], s.summary()["permits"])

    def test_discovery_after_prior_timeout_has_cumulative_cost(self):
        s = ExplorationSeries("s")
        close(s)
        close(s, run="next", episode="next", found=True)
        summary = s.summary()
        self.assertEqual(summary["discovery_day"], 2)
        self.assertEqual(summary["time_to_discovery_us"], 16270000)
        self.assertEqual(summary["distance_to_discovery"], 2)

    def test_30_days_1920_observations_and_replay_at_capacity(self):
        s = ExplorationSeries("s")
        first_request = None
        for day in range(30):
            start, request, receipt = close(s, run=f"r{day}", episode=f"e{day}", count=64)
            self.assertEqual(start["history_observations"], 64 * day)
            first_request = first_request or request
        summary = s.summary()
        self.assertEqual(summary["status"], "undiscovered_at_limit")
        self.assertEqual(summary["observations"], 1920)
        self.assertEqual(summary["consumed_exploration_us"], 480000000)
        for key in ("discovery_day", "time_to_discovery_us", "distance_to_discovery", "permits_to_discovery"):
            self.assertIsNone(summary[key])
        self.assertEqual(s.close_day(first_request)["day"], 1)
        with self.assertRaisesRegex(ValueError, "closed"):
            s.start_day(dict(episode_id="31", run_id="31"))

    def test_abort_distinct_from_undiscovered_and_no_retry_new_day(self):
        s = ExplorationSeries("s")
        close(s)
        s.start_day(dict(episode_id="next", run_id="next"))
        failed = s.abort("world_or_transport_error")
        self.assertEqual(failed, s.abort("world_or_transport_error"))
        self.assertEqual(s.summary()["status"], "mechanism_error")
        self.assertEqual(s.summary()["completed_days"], 1)
        with self.assertRaises(ValueError):
            s.start_day(dict(episode_id="new", run_id="new"))

    def test_partial_is_not_absence_or_failure_learning(self):
        s = ExplorationSeries("s", max_days=1)
        close(s, partial=True)
        self.assertEqual(s.snapshot()["days"][0]["metrics"]["incomplete_observations"], 1)
        self.assertEqual(s.summary()["status"], "undiscovered_at_limit")
        self.assertFalse(hasattr(s, "learn"))
        self.assertFalse(hasattr(s, "review"))

    def test_returns_and_inputs_do_not_alias_retained_state(self):
        s = ExplorationSeries("s")
        start, request, receipt = close(s)
        before = s.snapshot()
        start["request"]["run_id"] = "mutated"
        request["deliveries"].clear()
        receipt["metrics"]["observations"] = 999
        s.history()[0]["state"]["observations"].clear()
        s.snapshot()["days"].clear()
        self.assertEqual(s.snapshot(), before)

    def test_private_world_evidence_excluded_from_materials(self):
        from integrations.luanti.tests.check_exploration_series import deliveries
        source = dict(world=dict(private_positions=[1, 2, 3], deliveries=[
            dict(kind=d["kind"], request=d["request"], response_wire=json.dumps(d["response"]),
                 private_world_id="hidden") for d in trace("r")]))
        projected = deliveries(source)
        self.assertEqual(accepted_day(projected), accepted_day(trace("r")))
        self.assertNotIn("hidden", str(projected))

    def test_no_canonical_or_interaction_history_effect(self):
        from runtime.bridge import EXPERIENCE, CANONICAL_SIDECAR
        before = (EXPERIENCE.snapshot(), CANONICAL_SIDECAR.snapshot())
        s = ExplorationSeries("s")
        close(s); s.history(); s.summary()
        self.assertEqual(before, (EXPERIENCE.snapshot(), CANONICAL_SIDECAR.snapshot()))

    def test_real_62_episode_matrix(self):
        from integrations.luanti.tests.check_exploration_series import read_artifact, check_matrix
        path = Path(__file__).parent / "fixtures/luanti_l13r_replay.json.gz"
        summaries = check_matrix(read_artifact(path))
        self.assertEqual(sum(s["completed_days"] for s in summaries), 62)


if __name__ == "__main__":
    unittest.main()
