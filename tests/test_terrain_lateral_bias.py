from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest

from runtime.terrain_lateral_bias import calculate_lateral, LateralResourceExploration, SCHEMA
from runtime.terrain_resource_exploration import terrain_action
from runtime.subjective_movement_terrain import calculate_terrain
from test_subjective_movement_terrain import observation, item
from test_terrain_resource_exploration import Session as BaseSession, surface
from test_resource_exploration import config, material


def symmetric():
    return observation(food=[item("food",5,0)],obstacles=[item("obstacle",2,0)])


class Session(BaseSession):
    def __init__(self,bias="neutral",profile="steady",agent="npc_a"):
        self.multi=LateralResourceExploration("r",3)
        self.agent=agent;self.loop=self.multi.agents[agent];self.loop.profile=profile
        self.seq,self.revision,self.pose=0,0,f"r:{agent}:pose:0"
        self.c=config();self.c.update(schema=SCHEMA,agent_id=agent,selection_profile=profile,lateral_bias=bias)
        self.multi.configure(self.c)

    def symmetric_packet(self):
        p=self.packet();p["food"]["visible"]=[material(distance=5)]
        p["movement_surface"]=surface(p,[item("o",2,0)])
        return p


class LateralTests(unittest.TestCase):
    def test_symmetric_input_separates_left_neutral_right_without_world_truth(self):
        values=[calculate_lateral(symmetric(),b) for b in ("left","neutral","right")]
        self.assertEqual([v["selected_action"] for v in values],[["turn",-90],["wait",0],["turn",90]])
        self.assertEqual(values[0]["observed_terrain"],values[2]["observed_terrain"])
        for v in values:
            self.assertEqual(v["turn_hysteresis"],"disabled")
            self.assertTrue(all(r["turn_hysteresis_contribution"] is None for r in v["directional_samples"]))

    def test_forward_minimum_is_not_changed_into_a_side_turn(self):
        o=observation(food=[item("food",5,0)])
        for bias in ("left","neutral","right"):
            r=calculate_lateral(o,bias)
            self.assertEqual(r["selected_action"],["move",1])
            self.assertTrue(all(v["lateral_bias_contribution"]==0 for v in r["directional_samples"]))

    def test_strong_food_obstacle_and_physical_difference_override_bias(self):
        food=observation(food=[item("food",5,4)])
        obstacle=observation(food=[item("food",5,0)],obstacles=[item("o",2,1)])
        physical=symmetric();physical["ground"]["samples"][0]["height_delta"]=1
        for o in (food,obstacle,physical):
            baseline=terrain_action(calculate_terrain(o))[0]
            self.assertEqual(baseline[0],"turn")
            for bias in ("left","neutral","right"):
                self.assertEqual(calculate_lateral(o,bias)["selected_action"],baseline)

    def test_near_width_boundary_and_finite_contribution(self):
        for h,eligible in ((.049999,True),(.05,True),(.050001,False)):
            o=symmetric();o["ground"]["samples"][0]["height_delta"]=h
            r=calculate_lateral(o,"left")
            self.assertEqual(r["pairs"][1]["eligible"],eligible)
            self.assertTrue(all(abs(v["lateral_bias_contribution"])<=.05 for v in r["directional_samples"]))
        o=symmetric();o["food"]["items"][0]["right"]=.05
        self.assertEqual(calculate_lateral(o,"left")["selected_action"],["turn",-90])
        self.assertEqual(calculate_lateral(o,"right")["selected_action"],["turn",90])

    def test_large_cancelling_components_are_not_a_permitted_near_tie(self):
        o=symmetric();o["food"]["items"][0]["right"]=2
        t=calculate_terrain(o);left,right=t["directional_samples"][0],t["directional_samples"][-1]
        o["ground"]["samples"][-1]["height_delta"]=(left["food"]-right["food"])/2
        for bias in ("left","neutral","right"):
            r=calculate_lateral(o,bias);pair=r["pairs"][1]
            self.assertLess(pair["differences"]["total"],1e-8)
            self.assertGreater(pair["differences"]["physical"],.1)
            self.assertFalse(pair["eligible"])
            self.assertEqual(r["selected_action"],["wait",0])

    def test_excluded_surface_never_reenters_candidates(self):
        for status in ("blocked","no_surface"):
            o=symmetric();o["ground"]["samples"][0].update(status=status,height_delta=None)
            r=calculate_lateral(o,"left");row=r["directional_samples"][0]
            self.assertIsNone(row["observed_terrain_total"])
            self.assertIsNone(row["lateral_bias_contribution"])
            self.assertIsNone(row["final_total"])
            self.assertEqual(r["selected_action"],["turn",90])

    def test_incomplete_acquisition_is_not_zero_cost(self):
        for coverage in ("partial","unavailable"):
            o=symmetric();o["obstacles"].update(coverage=coverage,items=[])
            r=calculate_lateral(o,"right")
            self.assertEqual(r["selected_action"],["wait",0])
            self.assertTrue(all(v["final_total"] is None and v["lateral_bias_contribution"] is None for v in r["directional_samples"]))

    def test_mirrored_observation_and_bias_mirror_the_result(self):
        o=observation(food=[item("f",5,.05)],obstacles=[item("o",2,0)])
        mirror=deepcopy(o)
        for ch in ("food","obstacles"):
            for i in mirror[ch]["items"]:i["right"]*=-1
        for row in mirror["ground"]["samples"]:row["direction_deg"]*=-1
        a,b=calculate_lateral(o,"left"),calculate_lateral(mirror,"right")
        self.assertEqual(a["selected_action"][1],-b["selected_action"][1])
        rows={r["direction_deg"]:r for r in b["directional_samples"]}
        for r in a["directional_samples"]:self.assertAlmostEqual(r["final_total"],rows[-r["direction_deg"]]["final_total"])

    def test_renaming_and_reordering_cannot_select_a_side(self):
        o=observation(food=[item("f1",5,-.1),item("f2",5,.1)],obstacles=[item("o1",2,-.1),item("o2",2,.1)])
        other=deepcopy(o)
        for ch in ("food","obstacles"):
            other[ch]["items"].reverse()
            for i,v in enumerate(other[ch]["items"]):v["ref"]="renamed"+str(i)
        for b in ("left","neutral","right"):
            a,c=calculate_lateral(o,b),calculate_lateral(other,b)
            self.assertEqual(a["directional_samples"],c["directional_samples"])
            self.assertEqual(a["selected_action"],c["selected_action"])

    def test_input_and_output_are_independent(self):
        o=symmetric();before=deepcopy(o);r=calculate_lateral(o,"left")
        r["observed_terrain"]["evidence"]["food"]["items"].clear()
        self.assertEqual(o,before)
        self.assertEqual(calculate_lateral(o,"left")["selected_action"],["turn",-90])

    def test_config_is_explicit_frozen_and_rejected_atomically(self):
        s=Session("left");state=s.multi.snapshot()
        self.assertEqual(s.multi.configure(s.c)["lateral_bias"],"left")
        for value in ("right","LEFT",1,None,{}):
            c=dict(s.c,lateral_bias=value)
            with self.assertRaises(ValueError):s.multi.configure(c)
            self.assertEqual(state,s.multi.snapshot())
        c=dict(s.c);del c["lateral_bias"]
        with self.assertRaises(ValueError):s.multi.configure(c)
        self.assertEqual(state,s.multi.snapshot())

    def test_bias_does_not_publish_when_run_binding_is_wrong(self):
        loop=LateralResourceExploration("r",3);before=loop.snapshot()
        c=config();c.update(schema=SCHEMA,run_id="other",selection_profile="steady",lateral_bias="left")
        with self.assertRaises(ValueError):loop.configure(c)
        self.assertEqual(before,loop.snapshot())

    def test_same_agent_can_have_either_bias_independent_of_profile_and_id(self):
        for agent in ("npc_a","npc_b","npc_c"):
            for profile in ("steady","curious","restless"):
                for bias,angle in (("left",-90),("right",90)):
                    s=Session(bias,profile,agent)
                    self.assertEqual(s.apply(s.symmetric_packet())[0]["amount"],angle)

    def test_replay_and_other_agents_do_not_accumulate_or_inherit_bias(self):
        s=Session("left");other=s.multi.agents["npc_b"].snapshot();p=s.symmetric_packet()
        first=s.multi.observe(p);state=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            replies=list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(r["command"]==first["command"] and r["new_frames"]==0 for r in replies))
        self.assertEqual(s.multi.snapshot(),state)
        self.assertEqual(s.multi.agents["npc_b"].snapshot(),other)

    def test_no_hysteresis_or_new_turn_budget_is_present(self):
        s=Session("left")
        for _ in range(3):
            c,_=s.apply(s.symmetric_packet())
            self.assertEqual((c["kind"],c["amount"]),("turn",-90))
            d=next(reversed(s.loop.decisions.values()))
            self.assertNotIn("steering",d)
            self.assertEqual(d["lateral"]["turn_hysteresis"],"disabled")

    def test_world_launcher_rejects_combining_the_two_experiments(self):
        from integrations.luanti.tests.run_multi_resource import run
        with self.assertRaisesRegex(ValueError,"lateral bias only mode"):
            run("natural_meadow",2,"mixed","unused",steering=True,lateral="neutral")

    def test_pickup_learning_and_variation_are_unchanged(self):
        a=Session("left",profile="restless");b=BaseSession()
        for s in (a,b):
            s.learn()
            for _ in range(3):s.apply(s.packet())
        self.assertEqual(a.loop.commands,b.loop.commands)
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.model.to_json(),b.loop.model.to_json())

    def test_neutral_replays_the_actual_v1_commands_and_learning(self):
        matrix=json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l15a_connection_replay.json.gz").read_bytes()))
        data=matrix["runs"][0]["data"];w=data["world"];loop=LateralResourceExploration(w["run_id"],2)
        for delivery in w["deliveries"]:
            p=deepcopy(delivery["request"]);kind=delivery["kind"]
            if kind=="configure":p.update(schema=SCHEMA,lateral_bias="neutral")
            reply=getattr(loop,kind)(p)
            if kind=="observe":self.assertEqual(reply["command"],json.loads(delivery["response_wire"])["command"])
        for aid,a in loop.agents.items():
            prior=data["runtime"]["exploration"]["agents"][aid]
            self.assertEqual(a.learning,prior["learning"])
            self.assertEqual(a.snapshot()["active_model"],prior["active_model"])


class RealLateralTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.primary=json.loads(gzip.decompress((Path(__file__).parent/
            "fixtures/luanti_l15a_lateral_replay.json.gz").read_bytes()))
        cls.followup=json.loads(gzip.decompress((Path(__file__).parent/
            "fixtures/luanti_l15a_lateral_followup.json.gz").read_bytes()))

    def test_all_eight_world_runs_replay_wire_geometry_bias_and_effects(self):
        from integrations.luanti.tests.check_terrain_lateral import check, decision_links
        self.assertEqual(len(self.primary["runs"]),6)
        self.assertEqual(len(self.followup["runs"]),2)
        for run in self.primary["runs"]+self.followup["runs"]:
            self.assertEqual(check(run["data"]),run["summary"])
            self.assertEqual(decision_links(run["data"]),run["decision_links"])
            for aid,a in run["data"]["runtime"]["exploration"]["agents"].items():
                self.assertEqual(len(a["observations"]),128)
                self.assertEqual(len(a["results"]),128)
                for source,next_source in run["decision_links"][aid].items():
                    if next_source is not None:
                        self.assertLess(a["observations"][source]["capture_us"],a["observations"][next_source]["capture_us"])

    def test_primary_absence_of_bias_effect_is_not_hidden(self):
        for run in self.primary["runs"]:
            self.assertEqual(run["summary"]["total_pickups"],0)
            for a in run["summary"]["agents"].values():
                self.assertEqual(a["lateral"]["counts"]["nonzero_contribution"],0)
                self.assertEqual(a["lateral"]["counts"]["changed_action"],0)
        for start in (0,3):
            reference=self.primary["runs"][start]["summary"]
            for run in self.primary["runs"][start+1:start+3]:
                self.assertEqual(run["summary"]["movement"],reference["movement"])
                for aid,a in run["summary"]["agents"].items():
                    self.assertEqual(a["lateral"]["final_position"],reference["agents"][aid]["lateral"]["final_position"])

    def test_followup_changes_one_real_choice_from_the_same_observed_components(self):
        left,right=self.followup["runs"]
        self.assertEqual(left["summary"]["agents"]["npc_b"]["lateral"]["counts"]["changed_action"],0)
        self.assertEqual(right["summary"]["agents"]["npc_b"]["lateral"]["counts"]["changed_action"],1)
        la=left["data"]["runtime"]["exploration"]["agents"]["npc_b"]
        ra=right["data"]["runtime"]["exploration"]["agents"]["npc_b"]
        for source,d in ra["decisions"].items():
            v=d["lateral"]
            if v and v["selected_action"]!=v["baseline_action"]:
                seq=ra["observations"][source]["sample_seq"]
                lp=next(p for p in la["observations"].values() if p["sample_seq"]==seq)
                lv=la["decisions"][lp["observation_id"]]["lateral"]
                components=lambda x:[tuple(row[k] for k in ("direction_deg","physical","food","obstacle","total"))
                    for row in x["observed_terrain"]["directional_samples"]]
                self.assertEqual(components(v),components(lv))
                self.assertNotEqual(v["selected_action"],lv["selected_action"])
                self.assertEqual(ra["results"]["op:"+source]["status"],"turned")
        self.assertNotEqual(left["summary"]["agents"]["npc_b"]["lateral"]["final_position"],
                            right["summary"]["agents"]["npc_b"]["lateral"]["final_position"])

    def test_followup_does_not_claim_oscillation_or_harvest_improvement(self):
        self.assertEqual(self.followup["provenance"]["phase"],"after-primary exploratory diagnostic")
        left,right=self.followup["runs"]
        self.assertEqual([r["summary"]["total_pickups"] for r in (left,right)],[0,0])
        self.assertEqual(left["summary"]["movement"]["npc_b"]["consecutive_reversals"],62)
        self.assertEqual(right["summary"]["movement"]["npc_b"]["consecutive_reversals"],63)


if __name__=="__main__":unittest.main()
