from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import gzip
import json
from math import hypot
from pathlib import Path
import unittest

from runtime.terrain_steering import SteeredResourceExploration, SCHEMA
from runtime.terrain_resource_exploration import TerrainResourceExploration
from test_terrain_resource_exploration import Session as V1Session, surface
from test_resource_exploration import config, material


class Session(V1Session):
    def __init__(self, profile="restless", agent="npc_a"):
        self.multi=SteeredResourceExploration("r",3)
        self.agent=agent;self.loop=self.multi.agents[agent];self.loop.profile=profile
        self.seq,self.revision,self.pose=0,0,f"r:{agent}:pose:0"
        c=config();c.update(schema=SCHEMA,agent_id=agent,selection_profile=profile)
        self.multi.configure(c)


def food_packet(session, forward=5, right=0):
    p=session.packet()
    p["food"]["visible"]=[dict(material(distance=hypot(forward,right)),forward=forward,right=right)]
    return p


class SteeringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old=json.loads(gzip.decompress((Path(__file__).parent/
            "fixtures/luanti_l15a_connection_replay.json.gz").read_bytes()))

    def pair(self, run=1, agent="npc_b", mutate=None, report=True):
        data=self.old["runs"][run]["data"];world=data["world"];a=world["agents"][agent]
        acts=a["actions"];loop=SteeredResourceExploration(world["run_id"],2)
        c=deepcopy(a["config"]);c["schema"]=SCHEMA;loop.configure(c)
        packets={o["packet"]["observation_id"]:o["packet"] for o in a["observations"]}
        for prev,cur in zip(acts,acts[1:]):
            pc,cc=prev["command"],cur["command"]
            if (pc["reason"].startswith("observed_material_terrain") and cc["reason"].startswith("observed_material_terrain")
                and pc["kind"]==cc["kind"]=="turn" and pc["amount"]==-cc["amount"]):
                first=deepcopy(packets[pc["source_id"]]);second=deepcopy(packets[cc["source_id"]])
                command=loop.observe(first)["command"]
                self.assertEqual(command,pc)  # actual first turn is lawful under both controllers
                if report:loop.result(deepcopy(prev["result"]))
                if mutate:mutate(second)
                return loop,second,agent
        self.fail("missing actual oscillation pair")

    def test_small_gap_holds_heading_in_recorded_meadow(self):
        loop,p,agent=self.pair(run=0)
        c=loop.observe(p)["command"];d=loop.agents[agent].decisions[p["observation_id"]]
        self.assertEqual(c["kind"],"move")
        self.assertTrue(c["reason"].endswith("heading_held"))
        self.assertLess(d["steering"]["forward_gap"],.02)

    def test_confirmed_turn_moves_once_instead_of_recorded_ninety_degree_reversal(self):
        loop,p,agent=self.pair()
        c=loop.observe(p)["command"];meta=loop.agents[agent].decisions[p["observation_id"]]["steering"]
        self.assertTrue(c["reason"].endswith("confirmed_turn_step"))
        self.assertEqual(c["kind"],"move")
        self.assertGreater(meta["forward_gap"],.9)
        self.assertTrue(all(meta["step_recheck"]["checks"].values()))

    def test_second_small_gap_woodland_case(self):
        loop,p,agent=self.pair(agent="npc_c")
        self.assertTrue(loop.observe(p)["command"]["reason"].endswith("heading_held"))

    def test_missing_rotation_receipt_never_authorizes_a_step(self):
        loop,p,_=self.pair(report=False)
        c=loop.observe(p)["command"]
        self.assertEqual(c["kind"],"wait")
        self.assertEqual(c["reason"],"body_correspondence_unavailable")

    def test_partial_after_turn_remains_nonnumeric_wait(self):
        def mutate(p):p["movement_surface"]["obstacles"]["coverage"]="partial"
        loop,p,agent=self.pair(mutate=mutate)
        self.assertEqual(loop.observe(p)["command"]["kind"],"wait")
        self.assertEqual(loop.agents[agent].decisions[p["observation_id"]]["movement_terrain"]["status"],"acquisition_incomplete")

    def test_newly_blocked_forward_stops_reversal_and_does_not_force_move(self):
        def mutate(p):p["movement_surface"]["ground"]["samples"][2].update(status="blocked",height_delta=None)
        loop,p,agent=self.pair(mutate=mutate)
        c=loop.observe(p)["command"];d=loop.agents[agent].decisions[p["observation_id"]]
        self.assertEqual(c["kind"],"wait")
        self.assertTrue(c["reason"].endswith("reversal_stopped"))
        self.assertIsNone(d["approach"])
        self.assertTrue(d["steering"]["stopped_targets"])

    def test_current_body_mismatch_keeps_existing_wait(self):
        def mutate(p):
            p["pose_ref"]+="-other"
            p["distant"]["observer_frame_ref"]=p["pose_ref"]
            for key in ("ground","obstacles"):p["movement_surface"][key]["source"]["pose_ref"]=p["pose_ref"]
        loop,p,_=self.pair(mutate=mutate)
        self.assertEqual(loop.observe(p)["command"]["reason"],"body_correspondence_unavailable")

    def test_turn_exit_postpones_only_active_approach_not_other_visible_food(self):
        def mutate(p):
            p["food"]["visible"].append(dict(p["food"]["visible"][0],ref="other-food"))
            p["movement_surface"]["ground"]["samples"][2].update(status="blocked",height_delta=None)
        loop,p,agent=self.pair(mutate=mutate)
        loop.observe(p);d=loop.agents[agent].decisions[p["observation_id"]]
        self.assertTrue(d["reason"].endswith("reversal_stopped"))
        self.assertEqual(d["steering"]["stopped_targets"],[p["food"]["visible"][0]["ref"]])
        self.assertNotIn("other-food",d["blocked_targets"])

    def test_changed_food_does_not_inherit_the_old_step(self):
        def mutate(p):
            for item in p["food"]["visible"]:item["ref"]+="-new"
        loop,p,agent=self.pair(mutate=mutate)
        c=loop.observe(p)["command"];meta=loop.agents[agent].decisions[p["observation_id"]]["steering"]
        self.assertFalse(meta["step_recheck"]["checks"]["same_food"])
        self.assertEqual(c["kind"],"wait")

    def test_increased_forward_height_does_not_inherit_the_old_step(self):
        def mutate(p):p["movement_surface"]["ground"]["samples"][2]["height_delta"]=1
        loop,p,agent=self.pair(mutate=mutate)
        c=loop.observe(p)["command"];meta=loop.agents[agent].decisions[p["observation_id"]]["steering"]
        self.assertFalse(meta["step_recheck"]["checks"]["physical_not_worse"])
        self.assertEqual(c["kind"],"wait")

    def test_new_obstacle_does_not_inherit_the_old_step(self):
        def mutate(p):
            p["movement_surface"]["obstacles"]["items"]=[dict(ref="new-near",forward=1,right=0)]
        loop,p,agent=self.pair(mutate=mutate)
        c=loop.observe(p)["command"];meta=loop.agents[agent].decisions[p["observation_id"]]["steering"]
        self.assertFalse(meta["step_recheck"]["checks"]["obstacle_not_worse"])
        self.assertNotEqual(c["kind"],"move")

    def test_two_same_direction_turns_then_stop_and_return_to_exploration(self):
        s=Session()
        commands=[]
        for index in range(3):
            p=food_packet(s,1,5);p["food"]["visible"][0]["ref"]=f"m{index}"
            commands.append(s.apply(p)[0])
        self.assertEqual([(c["kind"],c["amount"]) for c in commands],[("turn",90),("turn",90),("wait",0)])
        self.assertTrue(commands[-1]["reason"].endswith("turn_budget_stopped"))
        self.assertEqual(next(reversed(s.loop.decisions.values()))["steering"]["stopped_targets"],["m2"])
        p=food_packet(s,1,5);p["food"]["visible"][0]["ref"]="m2"
        c=s.apply(p)[0]
        self.assertTrue(c["reason"].startswith("landmark_"))
        self.assertEqual(s.loop.learning["records"],[])

    def test_one_completed_move_clears_the_turn_streak(self):
        s=Session();s.apply(food_packet(s,1,5))
        self.assertEqual(s.apply(food_packet(s,5,0))[0]["kind"],"move")
        c=s.apply(food_packet(s,1,5))[0]
        d=next(reversed(s.loop.decisions.values()))
        self.assertEqual(c["kind"],"turn")
        self.assertEqual(d["steering"]["turns_without_move"],0)
        self.assertIsNone(d["steering"]["previous_operation"])

    def test_turned_away_food_keeps_one_rechecked_step_without_inventing_frontal_food(self):
        data=self.old["runs"][0]["data"];world=data["world"];a=world["agents"]["npc_a"]
        loop=SteeredResourceExploration(world["run_id"],2)
        c=deepcopy(a["config"]);c["schema"]=SCHEMA;loop.configure(c)
        first,second=[deepcopy(o["packet"]) for o in a["observations"][:2]]
        self.assertEqual(loop.observe(first)["command"],a["actions"][0]["command"])
        loop.result(deepcopy(a["actions"][0]["result"]))
        c=loop.observe(second)["command"];d=loop.agents["npc_a"].decisions[second["observation_id"]]
        self.assertTrue(c["reason"].endswith("confirmed_turn_step"))
        self.assertIsNone(d["movement_terrain"])
        self.assertEqual(d["steering"]["current_recheck"]["evidence"]["food"]["items"],[])

    def test_expired_intent_is_not_carried_to_later_slot(self):
        loop,p,agent=self.pair()
        p["capture_us"]+=500000;p["sample_seq"]+=2
        p["distant"].update(sample_seq=p["sample_seq"],sampled_world_tick=p["sample_seq"],
            capture_window=dict(kind="instant",start_us=p["capture_us"],end_us=p["capture_us"]))
        for key in ("ground","obstacles"):p["movement_surface"][key]["source"]["capture_us"]=p["capture_us"]
        loop.observe(p)
        d=loop.agents[agent].decisions[p["observation_id"]]
        self.assertIsNone(d["steering"]["previous_operation"])
        self.assertFalse(d["reason"].endswith("confirmed_turn_step"))

    def test_replay_keeps_one_choice_and_one_temporal_state(self):
        loop,p,agent=self.pair();first=loop.observe(p);before=loop.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            replies=list(pool.map(loop.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(r["command"]==first["command"] and r["new_observations"]==0 for r in replies))
        self.assertEqual(before,loop.snapshot())

    def test_pickup_and_learning_priority_are_unchanged(self):
        a=Session();b=V1Session()
        for s in (a,b):
            s.learn()
            for _ in range(3):s.apply(s.packet())
        self.assertEqual(a.loop.commands,b.loop.commands)
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.model.to_json(),b.loop.model.to_json())

    def test_agent_state_and_schema_isolated(self):
        s=Session();before=s.multi.agents["npc_b"].snapshot();s.apply(food_packet(s,1,-5))
        self.assertEqual(s.multi.agents["npc_b"].snapshot(),before)
        c=config();c.update(schema=SCHEMA,selection_profile="steady")
        with self.assertRaises(ValueError):TerrainResourceExploration("r",3).configure(c)

    def test_mirror_turns_and_no_fixed_side(self):
        commands=[]
        for right in (-5,5):
            s=Session();commands.append(s.apply(food_packet(s,1,right))[0])
        self.assertEqual([c["amount"] for c in commands],[-90,90])


class RealSteeringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix=json.loads(gzip.decompress((Path(__file__).parent/
            "fixtures/luanti_l15a_steering_replay.json.gz").read_bytes()))

    def test_four_world_runs_replay_exact_commands_state_and_current_geometry(self):
        from integrations.luanti.tests.check_terrain_steering import check
        from integrations.luanti.tests.check_terrain_resource import check as old
        self.assertEqual(len(self.matrix["runs"]),4)
        for case,run in zip(self.matrix["provenance"]["predeclared"],self.matrix["runs"]):
            self.assertEqual((check if case["steering"] else old)(run["data"]),run["summary"])
            for agent in run["data"]["runtime"]["exploration"]["agents"].values():
                self.assertEqual(len(agent["observations"]),128)
                self.assertEqual(len(agent["commands"]),128)
                self.assertEqual(len(agent["results"]),128)

    def test_real_turn_reduction_and_remaining_limitations_are_both_preserved(self):
        from integrations.luanti.tests.check_terrain_steering import movement_metrics
        for old,new in zip(self.matrix["runs"][::2],self.matrix["runs"][1::2]):
            before,after=[movement_metrics(r["data"]) for r in (old,new)]
            self.assertEqual(after,new["movement"])
            self.assertGreater(sum(a["consecutive_reversals"] for a in before.values()),0)
            self.assertEqual(sum(a["consecutive_reversals"] for a in after.values()),0)
            self.assertLessEqual(max(a["max_consecutive_food_turns"] for a in after.values()),2)
            self.assertGreater(sum(a["food_locomotion_results"].get("moved",0) for a in after.values()),
                               sum(a["food_locomotion_results"].get("moved",0) for a in before.values()))
        meadow=self.matrix["runs"][1]["summary"]
        self.assertEqual(meadow["total_pickups"],8)
        self.assertTrue(meadow["agents"]["npc_c"]["learned"])
        self.assertEqual(meadow["agents"]["npc_a"]["pickups"],0)


if __name__=="__main__":unittest.main()
