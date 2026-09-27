from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import unittest

from runtime.resource_exploration import ResourceExploration, PERIOD_US
from runtime.exploration import RESOURCE_SCHEMA, FiniteExploration
from test_landmark_exploration import Session as LandmarkSession, feature
from test_exploration import result


def config(run="r"):
    return dict(schema=RESOURCE_SCHEMA,run_id=run,world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1",
        teaching=dict(statement_id="statement",source="god_statue",sample_observation="sample",
                      appearance="brown_capped_ovoid",predicate="food_after_known_processing"))


def material(ref="m",distance=1,appearance="brown_capped_ovoid"):
    return dict(ref=ref,distance=distance,forward=distance,right=0,up=0,appearance=appearance)


class Session(LandmarkSession):
    def __init__(self, periods=2):
        self.loop=ResourceExploration("r",periods,3);self.loop.configure(config())
        self.seq,self.revision,self.pose=0,0,"pose0"

    def apply(self,p,status=None):
        c=self.loop.observe(p)["command"]
        r=result(c,status or dict(move="moved",turn="turned",wait="waited",pickup="picked_up")[c["kind"]]);r["up"]=0
        self.revision=r["after_revision"];self.pose=f"r:pose:{self.revision}" if self.revision else "pose0"
        r["after_pose_ref"]=self.pose
        self.loop.result(r);self.seq+=1
        return c,r


class ResourceTests(unittest.TestCase):
    def test_new_schema_only_explicit_loop_and_teaching(self):
        with self.assertRaises(ValueError):FiniteExploration("r").configure(config())
        s=Session();before=s.loop.snapshot()
        for key,value in (("source","world_oracle"),("appearance","oak_tree"),("tree_color","brown")):
            c=config();c["teaching"][key]=value
            with self.assertRaises(ValueError):s.loop.configure(c)
            self.assertEqual(before,s.loop.snapshot())
        self.assertEqual(s.loop.configure(config())["teaching"],config()["teaching"])

    def test_only_taught_material_is_approached(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[material(distance=5)]
        self.assertEqual(s.loop.observe(p)["command"]["reason"],"observed_material_approach")
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[material(appearance="gray_round")]
        self.assertFalse(s.loop.observe(p)["command"]["reason"].startswith("observed_material_"))

    def test_untaught_material_does_not_count_as_food_in_survey(self):
        s=Session()
        for i in range(18):
            p=s.packet([feature(band="mid" if i==0 else "near")])
            p["food"]["visible"]=[material(appearance="gray_round")]
            s.apply(p)
        d=next(reversed(s.loop.decisions.values()))
        self.assertEqual(d["neighborhood"]["outcome"],"completed_no_food")
        self.assertFalse(d["neighborhood"]["survey"]["food_seen"])
        self.assertEqual(s.loop.snapshot()["inventory"],[])

    def test_two_actual_pickups_and_empty_observation_restart_search(self):
        s=Session()
        for _ in range(2):
            p=s.packet([feature()]);p["food"]["visible"]=[material()]
            c,r=s.apply(p);self.assertEqual(c["kind"],"pickup")
            self.assertFalse(s.loop.result(r)["new_result"])
        self.assertEqual(len(s.loop.snapshot()["inventory"]),2)
        p=s.packet([feature()]);c,r=s.apply(p)
        self.assertEqual(c["kind"],"move");self.assertTrue(c["reason"].startswith("landmark_"))
        self.assertIsNone(s.loop.ending)

    def test_no_runtime_two_pickup_switch_rule(self):
        # Resource quantity belongs to World. A different lawful World may still
        # expose a third unit: selector follows observation, not a hidden count.
        s=Session()
        for _ in range(3):
            p=s.packet([feature()]);p["food"]["visible"]=[material()]
            self.assertEqual(s.apply(p)[0]["kind"],"pickup")
        self.assertEqual(len(s.loop.snapshot()["inventory"]),3)

    def test_period_boundary_retains_inventory_and_expires_old_authority(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[material()];s.apply(p)
        s.seq=63;p=s.packet([feature()]);c=s.loop.observe(p)["command"]
        self.assertEqual(c["expires_us"],PERIOD_US)
        r=result(c,"expired");r.update(up=0,executed_us=PERIOD_US+1000);s.loop.result(r)
        s.seq=64;p=s.packet([feature()]);p["food"]["visible"]=[material(ref="next")]
        c,r=s.apply(p);self.assertEqual(c["kind"],"pickup")
        self.assertEqual(len(s.loop.snapshot()["inventory"]),2)
        self.assertEqual(s.loop.decisions[p["observation_id"]]["period"],1)

    def test_unknown_body_or_partial_acquisition_stays_unresolved(self):
        s=Session();p=s.packet([feature()]);s.loop.observe(p)
        s.seq=1;p=s.packet([feature()]);p["food"]["visible"]=[material()]
        self.assertEqual(s.loop.observe(p)["command"]["reason"],"body_correspondence_unavailable")
        s=Session();p=s.packet([feature()]);p["food"].update(coverage="partial",visible=[material()])
        self.assertEqual(s.loop.observe(p)["command"]["kind"],"wait")

    def test_blocked_approach_has_finite_retry_authority(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[material(distance=5)];s.apply(p,"blocked")
        p=s.packet([feature()]);p["food"]["visible"]=[material(distance=5)]
        c,r=s.apply(p)
        self.assertFalse(c["reason"].startswith("observed_material_"))
        self.assertEqual(s.loop.decisions[p["observation_id"]]["blocked_targets"],["m"])

    def test_invalid_sensor_admission_does_not_publish_decision(self):
        s=Session();p=s.packet([feature()]);p["distant"]["payload"]["world_truth"]=123
        before=s.loop.snapshot()
        with self.assertRaises(ValueError):s.loop.observe(p)
        self.assertEqual(before,s.loop.snapshot())
        p=s.packet([feature()]);p["food"]["visible"]=[dict(material(),remaining=2)]
        with self.assertRaises(ValueError):s.loop.observe(p)
        self.assertEqual(before,s.loop.snapshot())

    def test_atomic_concurrent_resend(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[material()]
        with ThreadPoolExecutor(4) as pool:rs=list(pool.map(s.loop.observe,[deepcopy(p) for _ in range(8)]))
        self.assertEqual(sum(r["new_frames"] for r in rs),1)
        self.assertEqual(len(s.loop.commands),1)
        self.assertEqual(len(s.loop.snapshot()["inventory"]),0)
        self.assertEqual(len(s.loop.decisions),1)

    def test_non_object_result_rejected_before_inventory_access(self):
        s=Session();before=s.loop.snapshot()
        for value in (None,[],"result",1):
            with self.assertRaisesRegex(ValueError,"fields"):s.loop.result(value)
            self.assertEqual(before,s.loop.snapshot())

    def test_time_limit_not_discovery_or_pickup_ends_series(self):
        s=Session();p=s.packet([feature()]);p["food"]["visible"]=[material()];s.apply(p)
        end=dict(run_id="r",agent_id="npc_a",world_epoch=1,ended_us=1000000,reason="acquired")
        with self.assertRaises(ValueError):s.loop.finish(end)
        end.update(reason="time_limit")
        with self.assertRaises(ValueError):s.loop.finish(end)
        end.update(ended_us=2*PERIOD_US);self.assertTrue(s.loop.finish(end)["accepted"])
        self.assertEqual(s.loop.observe(p)["new_frames"],0)

    def test_budget_and_inventory_capacity_are_explicit(self):
        for n in (0,31,True):
            with self.assertRaises(ValueError):ResourceExploration("r",n)
        s=Session()
        for i in range(32):
            p=s.packet([feature()]);p["food"]["visible"]=[material(ref=f"m{i}")];s.apply(p)
        p=s.packet([feature()]);p["food"]["visible"]=[material()];c=s.loop.observe(p)["command"]
        self.assertEqual((c["kind"],c["reason"]),("wait","inventory_capacity"))
        r=result(c,"picked_up");r["up"]=0;before=s.loop.snapshot()
        with self.assertRaisesRegex(ValueError,"inventory_capacity"):s.loop.result(r)
        self.assertEqual(before,s.loop.snapshot())


class RealResourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix=json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l14a_replay.json.gz").read_bytes()))

    def test_continuous_world_and_all_wire_replay(self):
        from integrations.luanti.tests.check_resource_exploration import check
        self.assertEqual(len(self.matrix["runs"]),3)
        for run in self.matrix["runs"]:
            self.assertEqual(check(run["data"]),run["summary"])

    def test_long_runs_do_not_reset_or_stop_at_discovery(self):
        for run in self.matrix["runs"]:
            w=run["data"]["world"];s=run["data"]["runtime"]["exploration"]
            self.assertEqual(s["ending"]["reason"],"time_limit")
            if w["control"]:continue
            self.assertEqual(len(w["observations"]),1920)
            self.assertEqual(len(w["periods"]),30)
            self.assertEqual(sum(p["remaining"] for p in w["final_stock"])+len(s["inventory"]),16)
            self.assertTrue(all(p["present"]==(p["remaining"]>0) for p in w["final_stock"]))
            self.assertTrue(all(d["model_ref"] is None for d in s["decisions"].values()))

    def test_failed_long_run_preserved_and_old_world_regression(self):
        from integrations.luanti.tests.check_exploration import check
        check(self.matrix["legacy_regression"])
        rejected=self.matrix["rejected_runs"]
        self.assertEqual(len(rejected),1)
        self.assertEqual(rejected[0]["status"],"rejected_stock_object_loss")
        self.assertTrue(any(p["remaining"]>0 and not p["present"] for p in rejected[0]["data"]["world"]["final_stock"]))


if __name__=="__main__":unittest.main()
