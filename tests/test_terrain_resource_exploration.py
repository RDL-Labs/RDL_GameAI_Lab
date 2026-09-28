from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from math import hypot
from pathlib import Path
import unittest

from runtime.terrain_resource_exploration import (
    TerrainResourceExploration, SCHEMA, SURFACE, CONTEXT, terrain_input,
)
from runtime.multi_resource_exploration import MultiResourceExploration, SCHEMA as LEGACY
from test_multi_resource_exploration import Session as LegacySession
from test_resource_exploration import config, material
from test_subjective_movement_terrain import observation, item


def surface(p, obstacles=()):
    o = observation(obstacles=obstacles)
    context = {k:p[k] for k in CONTEXT}
    for key in ("ground", "obstacles"):
        o[key]["source"] = dict(context, frame_id=p["observation_id"]+":"+key)
    return dict(schema=SURFACE, ground=o["ground"], obstacles=o["obstacles"])


class Session(LegacySession):
    def __init__(self, profile="restless", agent="npc_a"):
        self.multi = TerrainResourceExploration("r", 3)
        self.agent = agent
        self.loop = self.multi.agents[agent]
        self.loop.profile = profile
        self.seq,self.revision,self.pose = 0,0,f"r:{agent}:pose:0"
        c = config(); c.update(schema=SCHEMA,agent_id=agent,selection_profile=profile)
        self.multi.configure(c)

    def packet(self, food=True, complete=True):
        p = super().packet(food, complete)
        p["movement_surface"] = surface(p)
        return p


class TerrainResourceTests(unittest.TestCase):
    def approach(self, right=0, obstacle=()):
        s=Session();p=s.packet()
        p["food"]["visible"]=[dict(material(distance=hypot(5,right)),forward=5,right=right)]
        p["movement_surface"] = surface(p,obstacle)
        c=s.multi.observe(p)["command"]
        return s,p,c,s.loop.decisions[p["observation_id"]]

    def test_visible_food_controls_existing_command_and_operation_identity(self):
        s,p,c,d=self.approach()
        self.assertEqual((c["kind"],c["amount"]),("move",1))
        self.assertEqual(c["operation_id"],"op:"+p["observation_id"])
        self.assertEqual(d["movement_terrain"]["minimum_directions"],[0])
        self.assertEqual(c["expires_us"],p["capture_us"]+500000)

    def test_left_and_right_food_turns_are_mirrored(self):
        a=self.approach(-4)[2];b=self.approach(4)[2]
        self.assertEqual((a["kind"],a["amount"]),("turn",-45))
        self.assertEqual((b["kind"],b["amount"]),("turn",45))

    def test_obstacle_configuration_changes_actual_command(self):
        left=self.approach(obstacle=[item("o",2,-1)])[2]
        right=self.approach(obstacle=[item("o",2,1)])[2]
        symmetric=self.approach(obstacle=[item("o",2,0)])[2]
        self.assertEqual(left["amount"],45);self.assertEqual(right["amount"],-45)
        self.assertEqual(symmetric["kind"],"wait")
        self.assertTrue(symmetric["reason"].endswith("symmetric_minimum"))

    def test_multiple_food_is_composed_not_nearest_selected(self):
        s=Session();p=s.packet()
        p["food"]["visible"]=[dict(material(ref=ref,distance=hypot(4,4)),forward=4,right=sign*4)
                              for ref,sign in (("a",-1),("b",1))]
        c=s.multi.observe(p)["command"]
        self.assertEqual(c["kind"],"move")
        self.assertEqual(len(s.loop.decisions[p["observation_id"]]["movement_terrain"]["evidence"]["food"]["items"]),2)

    def test_missing_and_excluded_ground_wait_without_free_space_inference(self):
        for partial in (True,False):
            s=Session();p=s.packet();p["food"]["visible"]=[material(distance=5)]
            g=p["movement_surface"]["ground"]
            for row in g["samples"]:row.update(status="unavailable" if partial else "blocked",height_delta=None)
            if partial:g["coverage"]="partial"
            c=s.multi.observe(p)["command"]
            self.assertEqual(c["kind"],"wait")
            self.assertTrue(c["reason"].endswith("acquisition_incomplete" if partial else "no_supported_direction"))

    def test_food_partial_remains_existing_wait(self):
        s=Session();p=s.packet(complete=False)
        self.assertEqual(s.apply(p)[0]["kind"],"wait")
        self.assertIsNone(s.loop.decisions[p["observation_id"]]["movement_terrain"])

    def test_pickup_and_model_learning_keep_existing_authority(self):
        a=Session();b=LegacySession();a.learn();b.learn()
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.model.to_json(),b.loop.model.to_json())
        self.assertEqual(a.loop.commands,b.loop.commands)
        self.assertEqual(a.loop.results,b.loop.results)
        self.assertEqual(a.loop.learning["admission"]["status"],"ADOPTED")

    def test_variation_priority_and_empty_food_landmark_exploration_preserved(self):
        a=Session();b=LegacySession()
        for s in (a,b):
            s.learn()
            for _ in range(3):s.apply(s.packet())
            s.apply(s.packet(False))
        self.assertEqual(a.loop.commands,b.loop.commands)
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertTrue(any(d["exploration_started"] for d in a.loop.decisions.values()))
        self.assertTrue(all(d["movement_terrain"] is None for d in a.loop.decisions.values()))

    def test_no_result_or_stale_body_does_not_authorize_terrain_motion(self):
        s,p,_,_=self.approach();s.seq+=1
        p=s.packet();p["food"]["visible"]=[material(distance=5)]
        c=s.multi.observe(p)["command"]
        self.assertEqual(c["reason"],"body_correspondence_unavailable")
        self.assertEqual(c["kind"],"wait")

    def test_behind_food_is_not_projected_into_frontal_terrain(self):
        s=Session();p=s.packet();p["food"]["visible"]=[dict(material(distance=5),forward=-5)]
        c=s.multi.observe(p)["command"]
        self.assertEqual(c["kind"],"turn")
        self.assertEqual(s.loop.decisions[p["observation_id"]]["terrain_gate"],"no_front_food; existing_orientation")
        self.assertEqual(terrain_input(p,"brown_capped_ovoid")["food"]["items"],[])

    def test_body_context_and_frame_binding_rejected_atomically(self):
        for key,value in (("agent_id","npc_b"),("capture_us",42),("pose_ref","old"),
                          ("body_revision",1),("frame_id","other"),("run_id","other")):
            s=Session();p=s.packet();before=s.multi.snapshot()
            p["movement_surface"]["ground"]["source"][key]=value
            with self.assertRaises(ValueError):s.multi.observe(p)
            self.assertEqual(s.multi.snapshot(),before)

    def test_bad_extension_rejected_even_when_pickup_would_have_priority(self):
        for mutate in (lambda p:p.pop("movement_surface"),
                       lambda p:p["movement_surface"].update(obstacles=[]),
                       lambda p:p["movement_surface"].update(hidden_world={}),
                       lambda p:p["movement_surface"]["obstacles"].update(items=[item(str(i)) for i in range(9)])):
            s=Session();p=s.packet();before=s.multi.snapshot();mutate(p)
            with self.assertRaises(ValueError):s.multi.observe(p)
            self.assertEqual(s.multi.snapshot(),before)

    def test_legacy_refuses_new_mode_and_extension(self):
        s=LegacySession();c=config();c.update(schema=SCHEMA,selection_profile="restless")
        with self.assertRaises(ValueError):s.multi.configure(c)
        p=s.packet();p["movement_surface"]=surface(p)
        with self.assertRaises(ValueError):s.multi.observe(p)
        t=Session();c["schema"]=LEGACY
        with self.assertRaises(ValueError):t.multi.configure(c)

    def test_concurrent_replay_keeps_one_decision_and_returns_frozen_command(self):
        s,p,c,_=self.approach();before=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            replies=list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(r["command"]==c and r["new_frames"]==0 for r in replies))
        self.assertEqual(before,s.multi.snapshot())
        p["movement_surface"]["ground"]["samples"][0]["height_delta"]=1
        with self.assertRaisesRegex(ValueError,"observation_conflict"):s.multi.observe(p)
        self.assertEqual(before,s.multi.snapshot())

    def test_agents_and_outputs_are_independent(self):
        s=Session();before=s.multi.agents["npc_b"].snapshot();p=s.packet()
        p["food"]["visible"]=[material(distance=5)]
        r=s.multi.observe(p);r["command"]["amount"]=99
        self.assertEqual(before,s.multi.agents["npc_b"].snapshot())
        self.assertEqual(s.multi.observe(p)["command"]["amount"],1)

    def test_result_conflict_and_expiry_remain_existing_checks(self):
        s=Session();p=s.packet();p["food"]["visible"]=[material(distance=5)]
        c,r=s.apply(p)
        self.assertFalse(s.multi.result(r)["new_result"])
        r["forward"]=0
        with self.assertRaises(ValueError):s.multi.result(r)


class RealTerrainConnectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix=json.loads(gzip.decompress((Path(__file__).parent/
            "fixtures/luanti_l15a_connection_replay.json.gz").read_bytes()))

    def test_all_three_world_runs_replay_accepted_wire_and_conserve_stock(self):
        from integrations.luanti.tests.check_terrain_resource import check
        from integrations.luanti.tests.check_multi_resource import check as legacy
        self.assertEqual(len(self.matrix["runs"]),3)
        for case,run in zip(self.matrix["provenance"]["predeclared"],self.matrix["runs"]):
            self.assertEqual((check if case.get("terrain") else legacy)(run["data"]),run["summary"])

    def test_real_movement_pickup_learning_and_limits_are_distinct(self):
        control,woodland,off=[r["summary"] for r in self.matrix["runs"]]
        self.assertEqual(control["total_pickups"],12)
        self.assertEqual(woodland["total_pickups"],0)
        self.assertEqual(off["total_pickups"],24)
        self.assertTrue(control["agents"]["npc_a"]["learned"])
        self.assertEqual(sum(a["terrain_results"].get("moved",0) for a in control["agents"].values()),26)
        for run in self.matrix["runs"]:
            for a in run["data"]["runtime"]["exploration"]["agents"].values():
                self.assertEqual(len(a["observations"]),128)
                self.assertEqual(len(a["commands"]),128)
                self.assertEqual(len(a["results"]),128)


if __name__=="__main__":unittest.main()
