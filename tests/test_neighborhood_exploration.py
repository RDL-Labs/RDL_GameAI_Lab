from copy import deepcopy
from unittest.mock import patch
import unittest

from runtime.exploration import NEIGHBORHOOD_SCHEMA
from runtime.neighborhood_exploration import (NeighborhoodExplorationDay, NeighborhoodExplorationSeries,
    PLAN, PURPOSE, MAX_SURVEY_US, SURVEY, RELATION, make_candidate, inspect_day, descriptor, survey_outcome)
from runtime.landmark_exploration import LandmarkExplorationDay
from runtime.learned_exploration import observation_key
from runtime.exploration_series import digest
from test_landmark_exploration import Session as LandmarkSession, feature
from test_exploration import result


class Session(LandmarkSession):
    def __init__(self, loop=None):
        self.loop = loop or NeighborhoodExplorationDay("r","s",1,1)
        self.loop.configure(dict(schema=NEIGHBORHOOD_SCHEMA,run_id=self.loop.run_id,world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1"))
        self.seq,self.revision,self.pose = 0,0,"pose0"


def features(i):
    return [feature(band="mid" if i==0 else "near")] + ([feature(60,color="gray",band="far",name="p1")] if i else [])


def day(series, run, *, food_at=None, partial_at=None, uniform_counts=False):
    start = series.start_day(dict(episode_id=run,run_id=run))
    s = Session(series.loop)
    for i in range(18): s.feed(features(i)[:1] if uniform_counts else features(i),food=i==food_at,partial=i==partial_at)
    s.loop.finish(dict(run_id=run,world_epoch=1,agent_id="npc_a",ended_us=16000000,reason="time_limit"))
    return series.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))


class NeighborhoodTests(unittest.TestCase):
    def test_opt_in_and_old_controller_remains_separate(self):
        with self.assertRaises(ValueError): Session(LandmarkExplorationDay("r","s",1,1))
        s=Session(); s.feed(features(0)); d=s.feed(features(1))
        self.assertEqual(d["action"],list(SURVEY[0]))
        self.assertEqual(d["neighborhood"]["phase"],"survey")

    def test_complete_two_returns_no_food_is_not_absence(self):
        s=Session()
        for i in range(18): d=s.feed(features(i))
        n=d["neighborhood"]
        self.assertEqual(n["outcome"],"completed_no_food")
        self.assertEqual(len(n["survey"]["return_sources"]),2)
        self.assertEqual(survey_outcome(s.loop.snapshot(),1,17,descriptor(features(1)[0])),"completed_no_food")
        self.assertEqual(d["action"],["wait",0])

    def test_blocked_or_incomplete_is_not_negative_support(self):
        for partial in (True,False):
            s=Session(); s.feed(features(0)); s.feed(features(1))
            s.feed(features(2),partial=partial,status=None if partial else "blocked")
            d=s.feed(features(3))
            self.assertIsNone(make_candidate(s.loop.snapshot(),"e","s"))
            self.assertNotEqual(d["neighborhood"]["outcome"],"completed_no_food")

    def test_return_anchor_missing_or_ambiguous_stays_incomplete(self):
        for fs,reason in (([],"anchor_lost"),([feature(-15,band="near"),feature(15,band="near",name="other")],"anchor_ambiguous")):
            s=Session()
            for i in range(9):s.feed(features(i))
            d=s.feed(fs)
            self.assertEqual(d["neighborhood"]["outcome"],reason)
            self.assertEqual(d["action"],["wait",0])

    def test_unconfirmed_result_stops_without_invented_return(self):
        s=Session();s.feed(features(0));s.feed(features(1),report=False)
        d=s.feed(features(2))
        self.assertEqual(d["neighborhood"]["outcome"],"body_correspondence_unavailable")

    def test_partial_day_does_not_form_no_discovery_candidate(self):
        s=NeighborhoodExplorationSeries("s");day(s,"partial",partial_at=3)
        self.assertIsNone(s.candidate)

    def test_wholly_incomplete_day_does_not_create_count_evidence(self):
        s=NeighborhoodExplorationSeries("s");start=s.start_day(dict(episode_id="missing",run_id="missing"))
        session=Session(s.loop)
        for i in range(18): session.feed(features(i),partial=True)
        s.loop.finish(dict(run_id="missing",world_epoch=1,agent_id="npc_a",ended_us=16000000,reason="time_limit"))
        s.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))
        self.assertIsNone(s.candidate)
        self.assertEqual(s.canonical.snapshot()["captures"],0)
        self.assertEqual(s.canonical.snapshot()["models"],{})
        next_start=s.start_day(dict(episode_id="next",run_id="next"))
        self.assertIsNone(next_start["model_ref"])
        self.assertFalse(s.summary()["adopted"])

    def test_formation_validation_then_active_model_changes_next_action(self):
        s=NeighborhoodExplorationSeries("s")
        day(s,"formation")
        self.assertEqual(s.candidate["common_relation_signature"]["kind"],RELATION)
        self.assertEqual(s.candidate["support_count"],1)
        self.assertIsNone(s.learning)
        day(s,"validation")
        self.assertEqual(s.inspection["disposition"],"RETAIN")
        self.assertTrue(s.learning["cutover"])
        day(s,"use")
        d=list(s.loop.decisions.values())[1]
        self.assertEqual(d["action"],["wait",0])
        self.assertEqual(d["neighborhood"]["outcome"],"active_M_B_no_food")

    def test_same_history_without_cutover_repeats_survey(self):
        s=NeighborhoodExplorationSeries("s",mode="inspect")
        day(s,"formation");day(s,"validation");day(s,"inactive")
        d=list(s.loop.decisions.values())[1]
        self.assertEqual(d["action"],list(SURVEY[0]))
        self.assertEqual(d["neighborhood"]["prediction"]["status"],"unknown")

    def test_food_anywhere_in_inspection_window_is_counterexample(self):
        s=NeighborhoodExplorationSeries("s");day(s,"formation");day(s,"counterexample",food_at=7)
        self.assertEqual(s.inspection["disposition"],"REJECT")
        self.assertIsNone(s.learning)

    def test_partial_validation_defers_and_episode_alias_rejects(self):
        s=NeighborhoodExplorationSeries("s");day(s,"formation");day(s,"partial",partial_at=6)
        self.assertEqual(s.inspection["disposition"],"DEFER")
        with self.assertRaises(ValueError):inspect_day(s.candidate,s.loop.snapshot(),"formation")

    def test_model_scope_does_not_reject_other_appearances_or_plans(self):
        s=NeighborhoodExplorationSeries("s");day(s,"a");day(s,"b")
        r=s.candidate["common_relation_signature"];m=s.canonical.model_for_agent("npc_a")
        q=dict(series_id="s",agent_id="npc_a",purpose=PURPOSE,observed=r["start_observed"],anchor=r["anchor"],plan=PLAN,max_survey_us=MAX_SURVEY_US,food_observed=False)
        self.assertEqual(m.interpret_neighborhood(q)["predicts_food"],False)
        for key,value in (("series_id","other"),("plan","other"),("max_survey_us",MAX_SURVEY_US+1),("observed",None),("food_observed",True),("anchor",dict(r["anchor"],color="red"))):
            changed=deepcopy(q);changed[key]=value
            self.assertEqual(m.interpret_neighborhood(changed)["status"],"unknown")

    def test_replay_does_not_repeat_survey_or_increase_support(self):
        s=NeighborhoodExplorationSeries("s");receipt=day(s,"a");before=s.snapshot()
        self.assertEqual(s.close_day(s.days[0]["close_request"]),receipt)
        self.assertEqual(s.snapshot(),before)
        p=next(iter(s.loop.observations.values()));self.assertEqual(s.loop.observe(p)["new_frames"],0)
        self.assertEqual(s.candidate["support_count"],1)

    def test_failed_sleep_does_not_publish_partial_day_or_model(self):
        s=NeighborhoodExplorationSeries("s");start=s.start_day(dict(episode_id="a",run_id="a"));t=Session(s.loop)
        for i in range(18):t.feed(features(i))
        t.loop.finish(dict(run_id="a",world_epoch=1,agent_id="npc_a",ended_us=16000000,reason="time_limit"))
        before=s.snapshot();request=dict(**start["request"],state_digest=digest(t.loop.snapshot()))
        with patch.object(s,"canonical_builder",side_effect=ValueError("injected")):
            with self.assertRaises(ValueError):s.close_day(request)
        self.assertEqual(s.snapshot(),before)

    def test_no_actual_difference_does_not_fabricate_core_E(self):
        s=NeighborhoodExplorationSeries("s")
        day(s,"a",uniform_counts=True);day(s,"b",uniform_counts=True)
        self.assertEqual(s.inspection["disposition"],"RETAIN")
        self.assertEqual(s.learning["status"],"review_difference_unavailable")
        self.assertFalse(s.summary()["adopted"])
        self.assertTrue(all(p["E"]["is_zero"] for p in s.canonical.snapshot()["review_path"]["paths"]))

    def test_measured_return_failure_is_not_no_food_evidence(self):
        s=Session();s.feed(features(0));s.feed(features(1));s.feed(features(2),report=False)
        c=list(s.loop.commands.values())[-1];r=result(c,"moved");r.update(up=1,after_pose_ref="raised")
        s.loop.result(r);s.pose="raised";s.revision=r["after_revision"]
        for i in range(3,10):d=s.feed(features(i))
        self.assertEqual(d["neighborhood"]["outcome"],"return_not_confirmed")
        self.assertIsNone(make_candidate(s.loop.snapshot(),"e","s"))

    def test_elapsed_acquisition_time_bounds_survey(self):
        s=Session();s.feed(features(0));s.feed(features(1));s.seq=30
        d=s.feed(features(30))
        self.assertEqual(d["neighborhood"]["outcome"],"survey_deadline")
        self.assertEqual(d["action"],["wait",0])

    def test_positive_food_learning_path_is_preserved(self):
        s=NeighborhoodExplorationSeries("s");day(s,"a",food_at=17);day(s,"b",food_at=17)
        self.assertEqual(s.candidate["common_relation_signature"]["kind"],"l13s-observed-route-v1")
        self.assertTrue(s.summary()["adopted"])

    def test_revisit_seed_is_explicit_and_frozen_before_commands(self):
        s=NeighborhoodExplorationSeries("s");day(s,"a");day(s,"b")
        request=dict(episode_id="revisit",run_id="revisit")
        a=s.start_revisit_day(request,42)
        self.assertEqual(a["seed"],42)
        self.assertEqual(s.start_revisit_day(request,42),a)
        with self.assertRaises(ValueError):s.start_revisit_day(request,43)
        self.assertEqual(s.loop.seed,42)
        ordinary=NeighborhoodExplorationSeries("ordinary");day(ordinary,"a");day(ordinary,"b")
        ordinary.start_day(request);before=ordinary.snapshot()
        with self.assertRaises(ValueError):ordinary.start_revisit_day(request,42)
        self.assertEqual(ordinary.snapshot(),before)

    def test_negative_label_is_revalidated_against_actual_operation_records(self):
        s=Session()
        for i in range(18):s.feed(features(i))
        state=s.loop.snapshot();self.assertIsNotNone(make_candidate(state,"e","s"))
        corrupt=deepcopy(state)
        r=list(corrupt["results"].values())[2];r["up"]=1
        self.assertIsNone(make_candidate(corrupt,"e","s"))


class RealNeighborhoodReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import gzip, json
        from pathlib import Path
        cls.matrix = json.loads(gzip.decompress((Path(__file__).parent / "fixtures/luanti_l13v_replay.json.gz").read_bytes()))

    def test_complete_real_world_wire_and_learning_replay(self):
        from integrations.luanti.tests.check_learned_exploration import check_matrix
        summaries = check_matrix(self.matrix)
        self.assertEqual({s["config"]["schema"] for s in summaries}, {"l13v-neighborhood-exploration-v1"})
        self.assertEqual(len(summaries), 2)
        self.assertTrue(all(s["failure"] is None for s in summaries))

    def test_same_history_cutover_changes_measured_body_action(self):
        from integrations.luanti.tests.run_neighborhood_exploration import compare
        self.assertTrue(self.matrix["revisit_branches"])
        for b in self.matrix["revisit_branches"]:
            c = compare(b["active"], b["inactive"])
            self.assertEqual(c, b["comparison"])
            self.assertEqual(c["active_action"], ["wait", 0])
            self.assertEqual(c["inactive_action"], ["turn", -90])
            self.assertEqual(c["active_result"]["yaw"], 0)
            self.assertAlmostEqual(c["inactive_result"]["yaw"], -90, places=3)
            self.assertTrue(b["active"]["state"]["summary"]["adopted"])
            self.assertFalse(b["inactive"]["state"]["summary"]["adopted"])
            self.assertEqual(b["active"]["state"]["candidate"]["support_count"], 1)
            self.assertEqual(b["active"]["state"]["inspection"]["validation_count"], 1)

    def test_world_return_audit_is_independent_of_success_label(self):
        from integrations.luanti.tests.check_neighborhood_exploration import check_neighborhood_day
        for s in self.matrix["series"]:
            for day in s["days"]:
                data = day["data"]
                completed = [d["neighborhood"] for d in data["runtime"]["exploration"]["decisions"].values()
                             if d["neighborhood"]["phase"] == "completed"]
                if not completed:
                    continue
                check_neighborhood_day(data)
                altered = deepcopy(data)
                ident = completed[0]["survey"]["return_sources"][0]["observation_id"]
                o = next(o for o in altered["world"]["observations"] if o["packet"]["observation_id"] == ident)
                o["body"]["position"]["x"] += 1
                with self.assertRaises(AssertionError):
                    check_neighborhood_day(altered)
                return
        self.fail("real completed survey missing")


if __name__=="__main__":unittest.main()
