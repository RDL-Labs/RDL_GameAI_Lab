from copy import deepcopy
from math import hypot
from concurrent.futures import ThreadPoolExecutor
import unittest

from runtime.model_movement_field import project, GAIN
from runtime.subjective_movement_terrain import calculate_terrain
from runtime.terrain_resource_exploration import terrain_input, terrain_action
from runtime.landmark_return_campaign import ReturnCampaign, SCHEMA
from test_terrain_resource_exploration import Session as TerrainSession, surface
from test_resource_exploration import config, material


class CampaignSession(TerrainSession):
    def __init__(self, mode):
        self.multi=ReturnCampaign("r",3,mb_field_mode=mode)
        self.agent="npc_a";self.loop=self.multi.agents[self.agent]
        self.seq,self.revision,self.pose=4,0,"r:npc_a:pose:0"
        c=config();c.update(schema=SCHEMA,selection_profile="steady",mb_field_mode=mode)
        self.multi.configure(c)

    def packet(self,food=True,complete=True):
        p=super().packet(food,complete)
        p["skyline"]=dict(model="finite-elevated-fan-v1",coverage="complete",features=[],
            source={k:p[k] for k in ("agent_id","observation_id","capture_us","pose_ref")})
        return p

    def ready_for_approach(self):
        self.learn()
        # Real model formation is via five distinct outcomes. End the pickup
        # prediction while food is still reachable, then enter another day.
        self.seq=128
        self.apply(self.packet())
        self.seq=260
        p=self.packet()
        p["food"]["visible"]=[dict(material(distance=hypot(5,3)),forward=5,right=3)]
        return p


class ModelFieldTests(unittest.TestCase):
    def setUp(self):
        self.s=CampaignSession("enabled")
        self.p=self.s.ready_for_approach()
        self.model=self.s.loop.model
        self.learning=deepcopy(self.s.loop.learning)
        self.t=calculate_terrain(terrain_input(self.p,"brown_capped_ovoid"))

    def test_adopted_sources_and_far_prediction_remains_unknown(self):
        out=project(self.t,self.p,self.model,self.learning,"enabled")
        field=out["model_field"]
        self.assertTrue(field["applied"])
        self.assertEqual(field["prediction"]["status"],"unknown")
        self.assertEqual((len(field["formation"]),len(field["validation"])),(3,2))
        self.assertTrue(all(-GAIN<=x["value"]<=0 for x in field["contributions"]))
        self.assertEqual(field["source_candidate"],self.learning["admission"]["candidate"]["candidate_id"])

    def test_disabled_preserves_geometry_and_choice(self):
        out=project(self.t,self.p,self.model,self.learning,"disabled")
        self.assertEqual(out["directional_samples"],self.t["directional_samples"])
        self.assertEqual(terrain_action(out),terrain_action(self.t))
        self.assertFalse(out["model_field"]["applied"])

    def test_no_model_and_invalidated_model_do_not_bias(self):
        for m,l,status in ((None,self.learning,"no_adopted_model"),
            (self.model,dict(self.learning,invalidated=True),"model_invalidated")):
            out=project(self.t,self.p,m,l,"enabled")
            self.assertEqual(out["directional_samples"],self.t["directional_samples"])
            self.assertEqual(out["model_field"]["status"],status)

    def test_missing_observation_and_profile_do_not_become_numeric_evidence(self):
        for field,value,status in (("coverage","PARTIAL","observation_incomplete"),
            ("profile_revision",2,"profile_mismatch")):
            p=deepcopy(self.p);p["distant"][field]=value
            out=project(self.t,p,self.model,self.learning,"enabled")
            self.assertFalse(out["model_field"]["applied"])
            self.assertEqual(out["model_field"]["status"],status)

    def test_excluded_geometry_never_reopens(self):
        p=deepcopy(self.p)
        p["movement_surface"]["ground"]["samples"][2].update(status="blocked",height_delta=None)
        t=calculate_terrain(terrain_input(p,"brown_capped_ovoid"))
        out=project(t,p,self.model,self.learning,"enabled")
        self.assertIsNone(out["directional_samples"][2]["total"])
        self.assertNotIn(0,out["minimum_directions"])

    def test_foreign_model_binding_and_future_sources_are_rejected(self):
        other=CampaignSession("enabled");other.learn()
        from dataclasses import replace
        model=replace(self.model,agent_id="npc_b")
        with self.assertRaisesRegex(ValueError,"model_field_agent"):
            project(self.t,self.p,model,self.learning,"enabled")
        t=deepcopy(self.t);t["context"]["pose_ref"]="foreign"
        with self.assertRaisesRegex(ValueError,"observation_binding"):
            project(t,self.p,self.model,self.learning,"enabled")
        l=deepcopy(self.learning);l["admission"]["records"][0]["later_us"]=self.p["capture_us"]+1
        with self.assertRaisesRegex(ValueError,"source_time"):
            project(self.t,self.p,self.model,l,"enabled")

    def test_pure_projection_does_not_modify_model_history_or_baseline(self):
        before=deepcopy((self.t,self.p,self.learning,self.model.to_json()))
        out=project(self.t,self.p,self.model,self.learning,"enabled")
        out["directional_samples"][0]["total"]=999
        self.assertEqual(before,(self.t,self.p,self.learning,self.model.to_json()))

    def test_current_campaign_uses_field_before_steering_and_replays_once(self):
        c=self.s.multi.observe(self.p)
        d=self.s.loop.decisions[self.p["observation_id"]]
        self.assertTrue(d["mb_field"]["field"]["applied"])
        self.assertEqual(d["mb_field"]["final_action"],[c["command"]["kind"],c["command"]["amount"]])
        before=self.s.loop.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            replies=list(pool.map(lambda _:self.s.multi.observe(deepcopy(self.p)),range(8)))
        self.assertTrue(all(x["command"]==c["command"] and x["new_observations"]==0 for x in replies))
        self.assertEqual(before,self.s.loop.snapshot())

    def test_pickup_night_and_return_keep_their_priority(self):
        for seq,expected in ((128,"return"),(224,"night")):
            s=CampaignSession("enabled");s.learn();s.seq=seq
            p=s.packet();c=s.multi.observe(p)["command"]
            d=s.loop.decisions[p["observation_id"]]
            self.assertEqual(d["day_cycle"]["phase"],expected)
            self.assertIsNone(d["mb_field"]["field"])
        s=CampaignSession("enabled");s.learn();p=s.packet()
        self.assertEqual(s.multi.observe(p)["command"]["kind"],"pickup")
        self.assertIsNone(s.loop.decisions[p["observation_id"]]["mb_field"]["field"])

    def test_disabled_campaign_has_same_command_and_learning(self):
        a=CampaignSession("enabled");b=CampaignSession("disabled")
        pa=a.ready_for_approach();pb=b.ready_for_approach()
        self.assertEqual(pa,pb)
        a.multi.observe(pa);b.multi.observe(pb)
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.model.to_json(),b.loop.model.to_json())
        self.assertFalse(b.loop.decisions[pb["observation_id"]]["mb_field"]["field"]["applied"])

    def test_same_observation_adopted_model_changes_final_action_via_field(self):
        agents=[CampaignSession(mode) for mode in ("disabled","enabled")]
        packets=[s.ready_for_approach() for s in agents]
        for p in packets:
            p["food"]["visible"]=[dict(material(distance=8),forward=0,right=8)]
            t=calculate_terrain(terrain_input(p,"brown_capped_ovoid"))
            rows={r["direction_deg"]:r for r in t["directional_samples"]}
            height=(rows[0]["food"]-rows[90]["food"]-.08)/2
            self.assertGreaterEqual(height,0)
            for row in p["movement_surface"]["ground"]["samples"]:
                if row["direction_deg"]==90:row["height_delta"]=height
                elif row["direction_deg"]!=0:row.update(status="blocked",height_delta=None)
        self.assertEqual(packets[0],packets[1])
        commands=[s.multi.observe(p)["command"] for s,p in zip(agents,packets)]
        self.assertEqual([c["kind"] for c in commands],["move","turn"])
        self.assertEqual(commands[1]["amount"],90)
        self.assertEqual(agents[0].loop.model.to_json(),agents[1].loop.model.to_json())
