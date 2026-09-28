import copy
import gzip
import json
from pathlib import Path
import unittest
from runtime.landmark_day_cycle import (DayCycleExploration, DayCycleAgent, home_review, phase,
    DAY_US, validate_skyline)


def state(): return dict(scans=0,operations=0,outcome=None,diagnostic=None,candidates=[])
def packet(features=None,coverage="complete"):
    return dict(agent_id="a",observation_id="o",capture_us=0,pose_ref="p",skyline=dict(
        model="finite-elevated-fan-v1",source=dict(agent_id="a",observation_id="o",capture_us=0,pose_ref="p"),
        coverage=coverage,features=features or []))
def feature(lo=-7.5,hi=7.5,band="far",color="ochre"):
    return dict(ref="r",color=color,azimuth=[lo,hi],elevation=15,range_band=band)


class DayCycleTests(unittest.TestCase):
    def test_phases_and_expiry_do_not_cross_authority_boundary(self):
        a=DayCycleAgent("run","npc_a","steady",3)
        for day in range(3):
            for t,name in ((0,"orientation"),(1000000,"exploration"),(32000000,"return"),(56000000,"night")):
                self.assertEqual(phase(day*DAY_US+t),name)
            for boundary in (1000000,32000000,56000000,64000000):
                self.assertEqual(a.expiry(day*DAY_US+boundary-1000),day*DAY_US+boundary)
        with self.assertRaises(ValueError): DayCycleExploration("run",4)

    def test_current_appearance_drives_homing_not_ref_or_location(self):
        p=packet([feature()]);s=state();before=copy.deepcopy((p,s))
        action,out=home_review(p,dict(color="ochre"),s,True,None)
        self.assertEqual(action,["move",1]);self.assertEqual((p,s),before)
        p["skyline"]["features"][0]["ref"]="new-frame-local-ref"
        self.assertEqual(home_review(p,dict(color="ochre"),s,True,None)[0],action)
        p["skyline"]["features"]=[feature(22.5,37.5)]
        self.assertEqual(home_review(p,dict(color="ochre"),s,True,None)[0],["turn",30])
        p["skyline"]["features"]=[feature(band="near")]
        action,out=home_review(p,dict(color="ochre"),s,True,None)
        self.assertEqual(out["outcome"],"home_like_observed")
        self.assertEqual(action,["wait",0])

    def test_lost_ambiguous_incomplete_not_fabricated_home(self):
        mem=dict(color="ochre")
        p=packet();s=state()
        for _ in range(4):
            action,s=home_review(p,mem,s,True,None);self.assertEqual(action,["turn",90])
        action,s=home_review(p,mem,s,True,None)
        self.assertEqual(s["outcome"],"not_observed")
        p=packet([feature(-70,-60),feature(60,70)])
        self.assertEqual(home_review(p,mem,state(),True,None)[1]["diagnostic"],"ambiguous")
        p=packet([feature(band="near")],"partial")
        action,s=home_review(p,mem,state(),True,None)
        self.assertEqual(action,["turn",90]);self.assertIsNone(s["outcome"])
        self.assertEqual(s["diagnostic"],"acquisition_incomplete")
        for _ in range(4): action,s=home_review(p,mem,s,True,None)
        self.assertEqual(action,["wait",0]);self.assertEqual(s["outcome"],"acquisition_incomplete")
        self.assertEqual(s["scans"],4)

    def test_blocked_unknown_and_operation_budget(self):
        for mem,linked,r,expected in ((None,True,None,"home_appearance_unavailable"),
            ({"color":"ochre"},False,None,"body_correspondence_unavailable"),
            ({"color":"ochre"},True,{"status":"blocked"},"blocked")):
            self.assertEqual(home_review(packet(),mem,state(),linked,r)[1]["outcome"],expected)
        s=state();s["operations"]=64
        self.assertEqual(home_review(packet([feature()]),{"color":"ochre"},s,True,None)[1]["outcome"],"operation_budget")

    def test_sensor_rejects_hidden_fields_and_cross_binding(self):
        p=packet([feature()]);validate_skyline(p)
        for key,val in (("world_id","tower"),("position",[0,0,0])):
            bad=copy.deepcopy(p);bad["skyline"]["features"][0][key]=val
            with self.assertRaises(ValueError):validate_skyline(bad)
        p["skyline"]["source"]["agent_id"]="other"
        with self.assertRaises(ValueError):validate_skyline(p)

    def test_saved_world_replay_and_retry(self):
        path=Path("tests/fixtures/luanti_l15a_landmark_day_cycle.json.gz")
        self.assertTrue(path.exists(), "World acceptance required")
        from integrations.luanti.tests.check_landmark_day_cycle import check
        with gzip.open(path,"rt",encoding="utf-8") as f: report=json.load(f)
        self.assertEqual(len(report["runs"]),1)
        for run in report["runs"]:
            self.assertEqual(check(run["data"]),run["summary"])
            w=run["data"]["world"]
            loop=DayCycleExploration(w["run_id"],3)
            tested=False
            for delivery in w["deliveries"]:
                name,p=delivery["kind"],delivery["request"]
                reply=getattr(loop,name)(p)
                if name=="observe" and phase(p["capture_us"])=="night" and not tested:
                    before=loop.snapshot();replay=loop.observe(p)
                    self.assertEqual(replay["new_observations"],0)
                    self.assertEqual(replay["command"],reply["command"])
                    self.assertEqual(before,loop.snapshot())
                    bad=copy.deepcopy(p);bad["skyline"]["source"]["agent_id"]="npc_b" if p["agent_id"]!="npc_b" else "npc_a"
                    with self.assertRaises(ValueError):loop.observe(bad)
                    self.assertEqual(before,loop.snapshot());tested=True
            self.assertTrue(tested)


if __name__=="__main__":unittest.main()
