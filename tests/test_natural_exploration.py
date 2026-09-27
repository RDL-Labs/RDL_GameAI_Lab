"""L13T acquisition/body contract; synthetic cases separate from real World replay."""
from copy import deepcopy
import gzip
import json
from math import sqrt
from pathlib import Path
import unittest

from runtime.exploration import FiniteExploration, NATURAL_SCHEMA, SCHEMA
from runtime.exploration_series import digest, day_metrics
from runtime.learned_exploration import LearnedExplorationDay, LearnedExplorationSeries, observation_key
from test_exploration import packet, result


def natural_packet(seq=0, run="r"):
    p = packet(seq, run)
    p["observation_id"] = run+f":o:{seq}"
    p["distant"]["frame_id"] = run+f":f:{seq}"
    p["ground"].update(model="l13t-local-surface-rays-v1", profile="l13t-natural-fixed-v1")
    for c in p["ground"]["cells"]: c["color"] = "green"
    return p


def configure(loop, schema=NATURAL_SCHEMA):
    loop.configure(dict(schema=schema, run_id=loop.run_id, world_epoch=1, agent_id="npc_a", clock_id="world-sim-v1"))


def natural_day(series, run, up=1):
    start = series.start_day(dict(episode_id=run, run_id=run))
    loop = series.loop
    configure(loop)
    revision, pose = 0, "pose0"
    for i in range(6):
        p = natural_packet(i, run)
        p.update(body_revision=revision, pose_ref=pose)
        p["distant"]["observer_frame_ref"] = pose
        if i >= 3:
            p["food"]["visible"] = [dict(ref=run+":food", forward=5, right=0, up=1, distance=sqrt(26))]
        c = loop.observe(p)["command"]
        r = result(c, {"move":"moved", "turn":"turned", "wait":"waited", "pickup":"picked_up"}[c["kind"]])
        r["up"] = up if r["status"] == "moved" else 0
        revision = r["after_revision"]
        pose = run+f":pose:{revision}"
        r["after_pose_ref"] = pose
        loop.result(r)
    loop.finish(dict(run_id=run, world_epoch=1, agent_id="npc_a", ended_us=16000000, reason="time_limit"))
    return series.close_day(dict(**start["request"], state_digest=digest(loop.snapshot())))


class NaturalExplorationTests(unittest.TestCase):
    def test_version_opt_in_and_ground_model_binding(self):
        with self.assertRaisesRegex(ValueError, "configuration"):
            configure(FiniteExploration("r"))
        loop = LearnedExplorationDay("r", "s", 1, 1); configure(loop)
        with self.assertRaisesRegex(ValueError, "ground_profile"): loop.observe(packet(run="r"))
        self.assertEqual(loop.observe(natural_packet())["new_frames"], 1)
        old = LearnedExplorationDay("r", "s", 1, 1); configure(old, SCHEMA)
        with self.assertRaisesRegex(ValueError, "ground_profile"): old.observe(natural_packet())

    def test_true_3d_food_range_and_no_hidden_map_admission(self):
        loop = LearnedExplorationDay("r", "s", 1, 1); configure(loop)
        p = natural_packet(); p["food"]["visible"] = [dict(ref="seen", forward=3, right=0, up=4, distance=5)]
        before = loop.snapshot()
        for change in (lambda q:q["food"]["visible"][0].update(distance=3),
                       lambda q:q["food"]["visible"][0].pop("up"),
                       lambda q:q.update(height_map=[]),
                       lambda q:q["ground"].update(food_direction="right")):
            q = deepcopy(p); change(q)
            with self.assertRaises(ValueError): loop.observe(q)
            self.assertEqual(loop.snapshot(), before)
        self.assertEqual(loop.observe(p)["new_frames"], 1)
        self.assertEqual(loop.observe(p)["new_frames"], 0)

    def test_measured_step_bounds_and_exact_replay(self):
        loop = LearnedExplorationDay("r", "s", 1, 1); configure(loop)
        loop.tape[0] = ["move", 1]
        c = loop.observe(natural_packet())["command"]
        r = dict(result(c), up=1)
        for up in (2, -2, .5, float("nan")):
            with self.assertRaises(ValueError): loop.result(dict(r, up=up))
        self.assertEqual(loop.results, {})
        self.assertTrue(loop.result(r)["new_result"])
        self.assertFalse(loop.result(r)["new_result"])
        with self.assertRaisesRegex(ValueError, "conflict"): loop.result(dict(r, up=-1))

    def test_blocked_cannot_report_vertical_movement(self):
        loop = LearnedExplorationDay("r", "s", 1, 1); configure(loop)
        loop.tape[0] = ["move", 1]
        c = loop.observe(natural_packet())["command"]
        r = dict(result(c, "blocked"), up=1)
        with self.assertRaisesRegex(ValueError, "vertical_effect"): loop.result(r)
        self.assertTrue(loop.result(dict(r, up=0))["new_result"])

    def test_colors_are_evidence_not_a_path_policy(self):
        actions = []
        for color in ("green", "brown", "gray", "blue"):
            loop = LearnedExplorationDay("r", "s", 1, 1); configure(loop)
            p = natural_packet()
            for c in p["ground"]["cells"]: c["color"] = color
            actions.append(loop.observe(p)["command"])
        self.assertTrue(all(c == actions[0] for c in actions))
        self.assertEqual(actions[0]["reason"], "neutral_sample")

    def test_incomplete_surface_stays_unknown(self):
        loop = LearnedExplorationDay("r", "s", 1, 1); configure(loop)
        p = natural_packet(); p["ground"]["coverage"] = "partial"
        p["ground"]["cells"][0].update(status="unloaded", color="unknown")
        self.assertIsNone(observation_key(p))
        self.assertEqual(loop.observe(p)["command"]["kind"], "wait")

    def test_sleep_and_t1_preserve_vertical_outcome(self):
        s = LearnedExplorationSeries("s")
        natural_day(s, "formation")
        trace = s.candidate["common_relation_signature"]["trace"]
        self.assertTrue(any(x["result_up"] == 1 for x in trace))
        natural_day(s, "validation")
        self.assertEqual(s.inspection["disposition"], "RETAIN")
        self.assertTrue(s.learning["cutover"])
        natural_day(s, "use")
        self.assertEqual(next(iter(s.loop.decisions.values()))["reason"], "active_M_B")

    def test_changed_vertical_result_aborts_validation(self):
        s = LearnedExplorationSeries("s")
        natural_day(s, "formation", 1)
        natural_day(s, "validation", -1)
        self.assertEqual(s.inspection["disposition"], "DEFER")
        self.assertIsNone(s.learning)

    def test_natural_distance_is_3d(self):
        s = LearnedExplorationSeries("s"); natural_day(s, "formation")
        state = s.loop.snapshot()
        count = sum(r["status"] == "moved" for r in state["results"].values())
        self.assertAlmostEqual(day_metrics(state)["distance"], count*sqrt(2))

    def test_old_model_cannot_match_new_acquisition_conditions(self):
        from test_learned_exploration import day
        s = LearnedExplorationSeries("s"); day(s, "old-formation"); day(s, "old-validation")
        s.start_day(dict(episode_id="new", run_id="new")); configure(s.loop)
        s.loop.observe(natural_packet(run="new"))
        decision = next(iter(s.loop.decisions.values()))
        self.assertEqual(decision["prediction"]["status"], "unknown")
        self.assertNotEqual(decision["reason"], "active_M_B")

    def test_contract_switch_rejects_without_publishing_a_day(self):
        s = LearnedExplorationSeries("s"); natural_day(s, "first")
        canonical = s.canonical.snapshot()
        start = s.start_day(dict(episode_id="changed", run_id="changed")); configure(s.loop, SCHEMA)
        s.loop.finish(dict(run_id="changed", world_epoch=1, agent_id="npc_a", ended_us=16000000, reason="time_limit"))
        with self.assertRaisesRegex(ValueError, "acquisition_contract_changed"):
            s.close_day(dict(**start["request"], state_digest=digest(s.loop.snapshot())))
        self.assertEqual(len(s.days), 1)
        self.assertEqual(s.canonical.snapshot(), canonical)
        self.assertEqual(s.pending, start)

    def test_unknown_http_endpoint_drains_a_bounded_body_before_404(self):
        from http.server import ThreadingHTTPServer
        from threading import Thread
        from urllib.request import Request, urlopen
        from urllib.error import HTTPError
        from runtime.learned_exploration_http import LearnedExplorationHandler
        server = ThreadingHTTPServer(("127.0.0.1", 0), LearnedExplorationHandler)
        thread = Thread(target=server.serve_forever, daemon=True); thread.start()
        try:
            for body in (b"", b"{}", b"not-json"*16000):
                with self.assertRaises(HTTPError) as caught:
                    urlopen(Request(f"http://127.0.0.1:{server.server_port}/v1/exploration/unknown", body), timeout=2)
                self.assertEqual(caught.exception.code, 404)
                self.assertEqual(json.load(caught.exception), {"error":"unknown_endpoint"})
                caught.exception.close()
        finally:
            server.shutdown(); server.server_close(); thread.join()

    def test_real_world_replay_and_measured_terrain_effects(self):
        from integrations.luanti.tests.check_learned_exploration import check_matrix
        from integrations.luanti.tests.check_exploration import check
        a = json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l13t_replay.json.gz").read_bytes()))
        summaries = check_matrix(a)
        self.assertEqual(a["capture_audit"]["unique_natural_runs"], 8)
        self.assertEqual(a["capture_audit"]["accepted_observations"], 512)
        for summary, s in zip(summaries, a["series"]):
            self.assertEqual([d["day"] for d in summary["discoveries"]], [2, 3, 4])
            self.assertTrue(summary["adopted"])
            results = [r for d in s["days"] for r in d["data"]["runtime"]["exploration"]["results"].values()]
            self.assertEqual(sum(r["status"] == "blocked" for r in results), 22)
            self.assertEqual(sum(abs(r["up"]) > .01 for r in results), 22)
            hidden = [o for d in s["days"] for o in d["data"]["world"]["observations"]
                      if o["food_visibility"]["in_range"] and not o["food_visibility"]["line_of_sight"]]
            self.assertEqual(len(hidden), 18)
            self.assertTrue(all(not o["packet"]["food"]["visible"] for o in hidden))
            trace = s["state"]["candidate"]["common_relation_signature"]["trace"]
            self.assertEqual(sum(t["result_status"] == "blocked" for t in trace), 3)
        self.assertEqual(check(a["legacy_regression"]["data"])["result"], "acquired")

    def test_corrupt_body_or_visibility_readback_is_rejected(self):
        from integrations.luanti.tests.check_natural_exploration import check_natural_day
        a = json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l13t_replay.json.gz").read_bytes()))
        data = a["series"][0]["days"][0]["data"]
        bad = deepcopy(data)
        moved = next(m for m in bad["world"]["terrain_moves"] if m["audit"]["reason"] == "supported_step")
        moved["audit"]["samples"][-1]["head"] = "rdl_bridge:exploration_trunk"
        with self.assertRaises(AssertionError): check_natural_day(bad)
        bad = deepcopy(a["series"][0]["days"][1]["data"])
        seen = next(o for o in bad["world"]["observations"] if o["packet"]["food"]["visible"])
        seen["food_visibility"]["line_of_sight"] = False
        with self.assertRaises(AssertionError): check_natural_day(bad)


if __name__ == "__main__": unittest.main()
