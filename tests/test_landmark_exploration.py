"""L13U synthetic acquisition/body controls; real replay is checked separately."""
from copy import deepcopy
from pathlib import Path
import gzip
import json
import unittest

from runtime.exploration import LANDMARK_SCHEMA
from runtime.landmark_exploration import LandmarkExplorationDay, LandmarkExplorationSeries, MODEL, PROFILE, validate_landmarks
from runtime.learned_exploration import LearnedExplorationDay, observation_key
from runtime.exploration_series import digest
from test_natural_exploration import natural_packet
from test_exploration import result


def feature(angle=0, color="brown", band="mid", name="patch0"):
    return dict(ref=name, color=color, azimuth=[angle-7.5, angle+7.5], range_band=band)


def frame(features):
    return dict(model=MODEL, profile=PROFILE, coverage="complete", output_limited=False, features=deepcopy(features))


class Session:
    def __init__(self, loop=None):
        self.loop = loop or LandmarkExplorationDay("r", "s", 1, 1)
        self.loop.configure(dict(schema=LANDMARK_SCHEMA, run_id=self.loop.run_id, world_epoch=1, agent_id="npc_a", clock_id="world-sim-v1"))
        self.seq, self.revision, self.pose = 0, 0, "pose0"

    def packet(self, features):
        p = natural_packet(self.seq, self.loop.run_id)
        p.update(body_revision=self.revision, pose_ref=self.pose, landmarks=frame(features))
        p["distant"]["observer_frame_ref"] = self.pose
        return p

    def feed(self, features, *, status=None, report=True, partial=False, food=False):
        p = self.packet(features)
        if partial: p["landmarks"]["coverage"] = "partial"
        if food: p["food"]["visible"] = [dict(ref="seen-food", distance=5, forward=5, right=0, up=0)]
        c = self.loop.observe(p)["command"]
        if report:
            r = result(c, status or {"move":"moved", "turn":"turned", "wait":"waited", "pickup":"picked_up"}[c["kind"]])
            r["up"] = 0
            self.revision = r["after_revision"]
            self.pose = self.loop.run_id+f":pose:{self.revision}" if self.revision else "pose0"
            r["after_pose_ref"] = self.pose
            self.loop.result(r)
        self.seq += 1
        return self.loop.decisions[p["observation_id"]]


def finish_day(series, run):
    start = series.start_day(dict(episode_id=run, run_id=run))
    session = Session(series.loop)
    for i in range(6): session.feed([feature(name=f"local-{i}")], food=i>=3)
    series.loop.finish(dict(run_id=run, world_epoch=1, agent_id="npc_a", ended_us=16000000, reason="time_limit"))
    return series.close_day(dict(**start["request"], state_digest=digest(series.loop.snapshot())))


class LandmarkExplorationTests(unittest.TestCase):
    def test_audit_rounding_matches_luanti_at_negative_half_nodes(self):
        from integrations.luanti.tests.check_landmark_exploration import round_node
        self.assertEqual([round_node(v) for v in (-1.5, -1.499, -.5, -.499, 0, .499, .5, 1.5)],
                         [-2, -1, -1, 0, 0, 0, 1, 2])

    def test_schema_is_explicit_and_legacy_rejects(self):
        with self.assertRaisesRegex(ValueError, "configuration"):
            Session(LearnedExplorationDay("r", "s", 1, 1))
        s = Session()
        d = s.feed([feature()])
        self.assertEqual(d["action"], ["move", 1])
        self.assertEqual(s.loop.draws, [])
        self.assertIsNone(d["bootstrap_action"])

    def test_malformed_configuration_rejects_without_state_change(self):
        loop = LandmarkExplorationDay("r", "s", 1, 1)
        before = loop.snapshot()
        for value in (None, [], "l13u", {"schema":"old"}):
            with self.assertRaisesRegex(ValueError, "landmark_configuration_required"):
                loop.configure(value)
            self.assertEqual(loop.snapshot(), before)

    def test_frame_budget_order_missing_and_hidden_fields(self):
        cases = [dict(frame([]), destination=[18,18]), dict(frame([]), model="unknown")]
        cases += [frame([feature(-30),feature(30)]), frame([feature(30,name="a"),feature(-30,name="b")])]
        cases += [frame([feature(-70+i*10, name=str(i)) for i in range(14)])]
        cases += [frame([dict(feature(), world_id="tree")]), frame([dict(feature(), range_band="unknown")])]
        for f in cases:
            with self.assertRaises(ValueError): validate_landmarks(f)

    def test_heading_correction_uses_reobserved_angle_and_keeps_goal(self):
        s = Session(); first = s.feed([feature(45)])
        self.assertEqual(first["action"], ["turn",45])
        second = s.feed([feature(0,name="renamed")])
        self.assertEqual(second["action"], ["move",1])
        self.assertEqual(first["landmark"]["goal"]["goal_id"],second["landmark"]["goal"]["goal_id"])
        self.assertEqual(second["landmark"]["selected_count"], 1)
        self.assertEqual(second["landmark"]["goal"]["current_feature"]["ref"], "renamed")

    def test_world_identity_is_not_in_feature_matching(self):
        s = Session(); s.feed([feature()])
        p = s.packet([feature(name="different-every-frame")])
        q = deepcopy(p); q["landmarks"]["features"][0]["ref"] = "another"
        self.assertEqual(observation_key(p), observation_key(q))
        self.assertEqual(s.feed([feature(name="different")])["landmark"]["stage"], "active")

    def test_correspondence_uses_measured_yaw_at_angular_gate(self):
        s = Session(); first = s.feed([feature(30)],report=False)
        c = next(iter(s.loop.commands.values()))
        r = result(c,"turned"); r.update(yaw=30.009, up=0, after_pose_ref="measured-pose")
        s.loop.result(r); s.pose = r["after_pose_ref"]; s.revision = r["after_revision"]
        # Inside the measured 15-degree gate, outside a command-only gate.
        d = s.feed([feature(-15.005)])
        self.assertEqual(d["landmark"]["stage"], "active")
        self.assertEqual(d["landmark"]["goal"]["goal_id"], first["landmark"]["goal"]["goal_id"])

    def test_lost_is_not_arrival_and_next_choice_is_observed(self):
        s = Session(); s.feed([feature()])
        d = s.feed([])
        self.assertEqual((d["action"], d["landmark"]["outcome"]), (["wait",0], "lost"))
        d = s.feed([feature(-30,color="gray",name="new")])
        self.assertEqual(d["action"], ["turn",-30])
        self.assertEqual(d["landmark"]["selected_count"], 2)

    def test_ambiguity_preserves_all_candidates_without_winner(self):
        s = Session(); s.feed([feature()])
        d = s.feed([feature(-15,name="left"),feature(15,name="right")])
        self.assertEqual(d["landmark"]["outcome"], "ambiguous")
        self.assertEqual(d["landmark"]["candidates"], ["left","right"])
        self.assertEqual(d["action"], ["wait",0])

    def test_blocked_stops_without_prescribed_detour(self):
        s = Session(); s.feed([feature()],status="blocked")
        d = s.feed([feature()])
        self.assertEqual(d["landmark"]["outcome"], "blocked")
        self.assertEqual(d["action"], ["wait",0])

    def test_near_observation_is_not_object_identity_or_food(self):
        s = Session(); s.feed([feature()])
        d = s.feed([feature(band="near")])
        self.assertEqual(d["landmark"]["outcome"], "near_feature_observed")
        self.assertTrue(all(not r["acquired"] for r in s.loop.results.values()))
        self.assertFalse(d["prediction"]["predicts_food"])

    def test_one_goal_has_twelve_operation_budget(self):
        s = Session(); first = s.feed([feature(band="far")])
        for i in range(11):
            d = s.feed([feature(band="far",name=f"f{i}")])
            self.assertEqual(d["landmark"]["goal"]["goal_id"],first["landmark"]["goal"]["goal_id"])
        d = s.feed([feature(band="far")])
        self.assertEqual(d["landmark"]["outcome"], "operation_budget")
        self.assertEqual(d["landmark"]["goal"]["operations"], 12)

    def test_no_feature_scans_are_bounded_without_blind_movement(self):
        s = Session()
        for _ in range(4): self.assertEqual(s.feed([])["action"], ["turn",90])
        d = s.feed([])
        self.assertEqual(d["action"], ["wait",0])
        self.assertEqual(d["landmark"]["outcome"], "no_candidate_after_scan")

    def test_eight_goal_limit_and_incomplete_is_not_empty(self):
        s = Session()
        for _ in range(8): s.feed([feature()]); s.feed([])
        d = s.feed([feature()])
        self.assertEqual(d["landmark"]["outcome"], "goal_budget")
        t = Session(); d = t.feed([],partial=True)
        self.assertEqual(d["landmark"]["outcome"], "acquisition_incomplete")
        self.assertEqual(d["landmark"]["scan_count"], 0)

    def test_unconfirmed_body_does_not_advance_goal(self):
        s = Session(); s.feed([feature(30)], report=False)
        d = s.feed([feature(0)])
        self.assertEqual(d["landmark"]["outcome"], "body_correspondence_unavailable")
        self.assertEqual(d["action"], ["wait",0])

    def test_replay_and_failed_admission_do_not_consume_a_selection(self):
        s = Session(); p = s.packet([feature()]); before = s.loop.snapshot()
        bad = deepcopy(p); bad["distant"]["payload"]["hidden"] = "world"
        with self.assertRaises(ValueError): s.loop.observe(bad)
        self.assertEqual(s.loop.snapshot(), before)
        r = s.loop.observe(p); after = s.loop.snapshot()
        self.assertEqual(s.loop.observe(p)["new_frames"], 0)
        self.assertEqual(s.loop.snapshot(), after)
        r["command"]["amount"] = 999
        self.assertNotEqual(s.loop.commands[p["observation_id"]]["amount"], 999)

    def test_selection_draw_depends_on_observed_choices_not_frame_ref(self):
        decisions = []
        for name in ("one", "another"):
            s = Session(); decisions.append(s.feed([feature(-30,name=name),feature(30,color="gray",name="b")]))
        self.assertEqual(decisions[0]["action"], decisions[1]["action"])
        self.assertEqual(decisions[0]["landmark"]["selection_index"], decisions[1]["landmark"]["selection_index"])

    def test_food_relation_is_learned_only_after_separate_day(self):
        s = LandmarkExplorationSeries("s")
        finish_day(s,"formation"); self.assertIsNone(s.learning)
        finish_day(s,"validation")
        self.assertEqual(s.inspection["disposition"], "RETAIN")
        self.assertTrue(s.learning["cutover"])
        finish_day(s,"use")
        first = next(iter(s.loop.decisions.values()))
        self.assertEqual(first["reason"], "active_M_B")
        self.assertEqual(first["landmark"]["stage"], "suspended")


class LandmarkRealReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix = json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l13u_replay.json.gz").read_bytes()))

    def test_exact_real_world_replay_and_bounded_outcomes(self):
        from integrations.luanti.tests.check_learned_exploration import check_matrix
        from integrations.luanti.tests.check_exploration import check
        from integrations.luanti.tests.summarize_landmark_exploration import summarize
        summaries = check_matrix(self.matrix)
        runs = set()
        for series, summary in zip(self.matrix["series"], summaries):
            metrics = summarize(series)
            self.assertIn(summary["status"], ("discovery_target_reached", "discovery_target_unmet_at_limit"))
            self.assertLessEqual(len(series["days"]), 30)
            self.assertEqual(len(series["state"]["days"]), len(series["days"]))
            self.assertEqual(len({d["start"]["request"]["episode_id"] for d in series["days"]}), len(series["days"]))
            self.assertGreater(metrics["goals_continued_after_body_result"], 0)
            self.assertGreater(metrics["goal_terminations"].get("ambiguous", 0), 0)
            for day in series["days"]:
                run = day["data"]["world"]["run_id"]
                self.assertNotIn(run, runs); runs.add(run)
                self.assertLessEqual(len(day["data"]["world"]["observations"]), 64)
            if summary["discovery_count"] == 0:
                self.assertFalse(summary["adopted"])
                self.assertIsNone(series["state"]["candidate"])
                self.assertTrue(all(d["receipt"]["sleep"]["status"] == "no_eligible_discovery_route" for d in series["days"]))
        self.assertEqual(len(runs), self.matrix["capture_audit"]["unique_landmark_runs"])
        self.assertEqual(check(self.matrix["legacy_regression"]["data"])["result"], "acquired")

    def test_real_small_turns_are_measured_from_body_readback(self):
        from math import degrees
        small_turns = 0
        for series in self.matrix["series"]:
            for day in series["days"]:
                for action in day["data"]["world"]["actions"]:
                    measured = (-degrees(action["after"]["yaw"]-action["before"]["yaw"])+180)%360-180
                    self.assertAlmostEqual(measured, action["result"]["yaw"], places=5)
                    if action["result"]["status"] == "turned":
                        amount = action["command"]["amount"]
                        self.assertEqual(amount%5, 0)
                        self.assertAlmostEqual(measured, amount, delta=.01)
                        if abs(amount) < 90: small_turns += 1
        self.assertGreater(small_turns, 0)

    def test_corrupted_ray_or_hidden_input_is_rejected(self):
        from integrations.luanti.tests.check_landmark_exploration import check_landmark_day
        data = self.matrix["series"][0]["days"][0]["data"]
        bad = deepcopy(data)
        ray = next(r for o in bad["world"]["observations"] for r in o["landmark_rays"] if r["status"] == "sampled")
        ray["hit"]["position"]["x"] += 1
        with self.assertRaises(AssertionError): check_landmark_day(bad)
        bad = deepcopy(data)
        bad["world"]["observations"][0]["packet"]["landmarks"]["world_destination"] = [18,18]
        with self.assertRaises(ValueError): check_landmark_day(bad)


if __name__ == "__main__": unittest.main()
