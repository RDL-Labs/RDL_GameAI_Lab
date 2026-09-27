from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest

from runtime.exploration import MULTIFOOD_SCHEMA
from runtime.multifood_exploration import MultiFoodExplorationDay, MultiFoodExplorationSeries
from runtime.neighborhood_exploration import NeighborhoodExplorationDay
from runtime.exploration_series import digest
from test_landmark_exploration import Session as LandmarkSession, feature
from test_exploration import result


def foods(n):
    return [dict(ref=f"f{i}",distance=5+i,forward=5+i,right=0,up=0) for i in range(n)]


class Session(LandmarkSession):
    def __init__(self, loop=None, count=0):
        self.loop=loop or MultiFoodExplorationDay("r","s",1,1)
        self.loop.configure(dict(schema=MULTIFOOD_SCHEMA,run_id=self.loop.run_id,world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1"))
        self.seq,self.revision,self.pose,self.count=0,0,"pose0",count

    def packet(self, features):
        p=super().packet(features)
        if self.seq>=3: p["food"]["visible"]=foods(self.count)
        return p


def day(s, name, count):
    start=s.start_day(dict(episode_id=name,run_id=name));t=Session(s.loop,count)
    for i in range(6): t.feed([feature()])
    s.loop.finish(dict(run_id=name,world_epoch=1,agent_id="npc_a",ended_us=16000000,reason="time_limit"))
    return s.close_day(dict(**start["request"],state_digest=digest(s.loop.snapshot())))


class MultiFoodTests(unittest.TestCase):
    def test_new_schema_is_opt_in(self):
        with self.assertRaises(ValueError):Session(NeighborhoodExplorationDay("r","s",1,1))
        self.assertEqual(Session().loop.snapshot()["schema"],MULTIFOOD_SCHEMA)
        from test_neighborhood_exploration import Session as OldSession
        old=OldSession();p=old.packet([feature()]);p["food"]["visible"]=foods(2)
        with self.assertRaisesRegex(ValueError,"food_budget"):old.loop.observe(p)

    def test_five_records_accepted_six_rejected_atomically(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=foods(6)
        before=s.loop.snapshot()
        with self.assertRaisesRegex(ValueError,"food_budget"):s.loop.observe(p)
        self.assertEqual(s.loop.snapshot(),before)
        p["food"]["visible"]=foods(5)
        self.assertTrue(s.loop.observe(p)["accepted"])
        self.assertEqual(s.loop.observe(p)["new_frames"],0)

    def test_duplicates_unsorted_and_hidden_coordinates_rejected(self):
        for values in ([foods(1)[0]]*2,list(reversed(foods(2))),[dict(foods(1)[0],world_position=[1,2,3])]):
            s=Session();p=s.packet([feature()]);p["food"]["visible"]=values
            before=s.loop.snapshot()
            with self.assertRaises(ValueError):s.loop.observe(p)
            self.assertEqual(s.loop.snapshot(),before)

    def test_nearest_observed_food_keeps_existing_pickup_rule(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[dict(ref="near",distance=1,forward=1,right=0,up=0)]+foods(2)
        c=s.loop.observe(p)["command"]
        self.assertEqual((c["kind"],c["target_ref"]),("pickup","near"))
        r=result(c,"picked_up");r["up"]=0;s.loop.result(r)
        self.assertEqual(s.loop.observe(p)["command"],c)

    def test_multiple_first_discoveries_keep_actual_E_count_and_one_support(self):
        for count in (1,2,5):
            s=MultiFoodExplorationSeries("s");day(s,"formation",count);day(s,"validation",count)
            self.assertEqual(s.inspection["disposition"],"RETAIN")
            self.assertTrue(s.summary()["adopted"])
            self.assertEqual(s.candidate["support_count"],1)
            self.assertEqual(s.summary()["discovery_count"],2)
            path=next(p for p in s.canonical.snapshot()["review_path"]["paths"]
                      if p["F_prime"]["source_observation_id"]==s.candidate["common_relation_signature"]["terminal_source"])
            self.assertEqual(path["E"]["deltas"]["visible_objects_count"],count)
            day(s,"use",count)
            self.assertEqual(s.summary()["discovery_count"],3)
            self.assertEqual(s.summary()["status"],"discovery_target_reached")
            self.assertTrue(any(d["reason"]=="active_M_B" for d in s.loop.decisions.values()))

    def test_more_items_do_not_rescue_failed_reobservation(self):
        s=MultiFoodExplorationSeries("s");day(s,"formation",5);day(s,"validation",0)
        self.assertEqual(s.inspection["disposition"],"REJECT")
        self.assertFalse(s.summary()["adopted"])


class RealMultiFoodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix=json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l13w_replay.json.gz").read_bytes()))

    def test_world_and_all_learning_wire_replay(self):
        from integrations.luanti.tests.check_learned_exploration import check_matrix
        from integrations.luanti.tests.check_exploration import check
        self.assertEqual(len(check_matrix(self.matrix)),2)
        check(self.matrix["legacy_regression"])

    def test_terrain_and_original_food_match_single_food_baseline(self):
        from integrations.luanti.tests.check_exploration_series import reset_signature
        baseline=json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l13v_replay.json.gz").read_bytes()))
        by={s["scenario"]:s for s in baseline["series"]}
        for s in self.matrix["series"]:
            initial=s["days"][0]["data"]
            signature=reset_signature(initial)
            self.assertEqual(len(signature.pop("foods")),5)
            self.assertEqual(signature,reset_signature(by[s["scenario"]]["days"][0]["data"]))
            self.assertEqual(s["config"]["seed"],20260927)
            self.assertEqual(s["config"]["max_days"],30)
            self.assertLessEqual(s["state"]["summary"]["discovery_count"],3)

    def test_resource_audit_cannot_silently_drop_a_visible_item(self):
        from integrations.luanti.tests.check_multifood_exploration import check_food_observation
        for s in self.matrix["series"]:
            for d in s["days"]:
                w=d["data"]["world"]
                for o in w["observations"]:
                    if o["packet"]["food"]["visible"]:
                        check_food_observation(w,o)
                        altered=deepcopy(o);altered["packet"]["food"]["visible"].pop()
                        with self.assertRaises((AssertionError,StopIteration)):check_food_observation(w,altered)
                        return
        # A zero-discovery result is valid; corrupt a recorded range instead.
        w=self.matrix["series"][0]["days"][0]["data"]["world"]
        altered=deepcopy(w["observations"][0]);altered["food_visibility"][0]["distance"]+=1
        with self.assertRaises(AssertionError):check_food_observation(w,altered)


if __name__=="__main__":unittest.main()
