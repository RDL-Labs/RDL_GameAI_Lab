from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import gzip
import json
from math import cos, sin, pi
from pathlib import Path
import unittest
from unittest.mock import patch

from runtime.terrain_tie_break import calculate_tie_break, sample, TieBreakResourceExploration, SCHEMA
from runtime.terrain_resource_exploration import terrain_action
from runtime.subjective_movement_terrain import calculate_terrain
from test_subjective_movement_terrain import observation, item
from test_terrain_resource_exploration import Session as BaseSession, surface
from test_resource_exploration import config, material


def symmetric():
    return observation(food=[item("f",5,0)],obstacles=[item("o",2,0)])


def evaluate(o, seed=20260928, mode="frozen", seq=1):
    return calculate_tie_break(o,mode,seed,seq)


class Session(BaseSession):
    def __init__(self,mode="frozen",profile="steady",agent="npc_a",seed=20260928):
        self.multi=TieBreakResourceExploration("r",3,seed=seed)
        self.agent=agent;self.loop=self.multi.agents[agent];self.loop.profile=profile
        self.seq,self.revision,self.pose=0,0,f"r:{agent}:pose:0"
        self.c=config();self.c.update(schema=SCHEMA,agent_id=agent,selection_profile=profile,tie_break_mode=mode)
        self.multi.configure(self.c)

    def tied_packet(self):
        p=self.packet();p["food"]["visible"]=[material(distance=5)]
        p["movement_surface"]=surface(p,[item("o",2,0)])
        return p

    def last(self):
        return next(reversed(self.loop.decisions.values()))["tie_break"]


class TieBreakTests(unittest.TestCase):
    def test_exact_symmetry_is_separated_without_altering_observed_terrain(self):
        before=symmetric();r=evaluate(before)
        self.assertEqual(r["eligible_directions"],[-90,90])
        self.assertIn(r["selected_action"],[["turn",-90],["turn",90]])
        self.assertEqual(r["observed_terrain"],calculate_terrain(before))
        self.assertEqual(evaluate(before,mode="disabled")["selected_action"],["wait",0])

    def test_seed_contract_and_five_unique_bounded_ranks(self):
        import hashlib
        r=sample(20260928,"r","npc_a",1)
        key=json.dumps(r["seed_inputs"],ensure_ascii=False,separators=(",",":"))
        self.assertEqual(r["seed"],hashlib.sha256(key.encode()).hexdigest())
        self.assertEqual(sorted(x["rank"] for x in r["vector"]),list(range(5)))
        self.assertEqual(sorted(x["perturbation"] for x in r["vector"]),[-.05,-.025,0,.025,.05])
        self.assertEqual(r,sample(20260928,"r","npc_a",1))
        for args in ((1,"r","npc_a",1),(20260928,"s","npc_a",1),
                     (20260928,"r","npc_b",1),(20260928,"r","npc_a",2)):
            self.assertNotEqual(r["seed"],sample(*args)["seed"])

    def test_flat_observed_zero_allows_forward_and_both_sides_without_unknowns(self):
        directions=set()
        for seed in range(32):
            r=evaluate(observation(),seed)
            self.assertEqual(len(r["eligible_directions"]),5)
            self.assertTrue(all(x["application_status"]=="applied" for x in r["directional_samples"]))
            a=r["selected_action"];directions.add(0 if a[0]=="move" else a[1])
            self.assertEqual(sum(x["tie_break_perturbation"]==0 for x in r["directional_samples"]),1)
        self.assertEqual(directions,{-90,-45,0,45,90})

    def test_near_width_boundary_is_finite(self):
        for height,allowed in ((.049999,True),(.05,True),(.050001,False)):
            o=symmetric();o["ground"]["samples"][0]["height_delta"]=height
            r=evaluate(o);self.assertEqual(bool(r["eligible_directions"]),allowed)

    def test_strong_difference_cannot_be_overridden(self):
        o=observation(food=[item("f",5,0)])
        expected=terrain_action(calculate_terrain(o))[0]
        for seed in range(16):
            r=evaluate(o,seed)
            self.assertEqual(r["selected_action"],expected)
            self.assertIsNone(r["sample"])

    def test_cancelling_large_components_is_not_a_weak_tie(self):
        o=symmetric();o["food"]["items"][0]["right"]=2
        t=calculate_terrain(o);left,right=t["directional_samples"][0],t["directional_samples"][-1]
        o["ground"]["samples"][-1]["height_delta"]=(left["food"]-right["food"])/2
        r=evaluate(o)
        self.assertEqual(r["eligibility_reason"],"component_difference_dominates")
        self.assertIsNone(r["sample"])

    def test_unknown_excluded_and_not_applicable_are_not_zero(self):
        for status in ("blocked","no_surface"):
            o=symmetric();o["ground"]["samples"][0].update(status=status,height_delta=None)
            r=evaluate(o);row=r["directional_samples"][0]
            self.assertIsNone(row["final_total"]);self.assertIsNone(row["tie_break_perturbation"])
            self.assertEqual(r["selected_action"],["turn",90])
        for coverage in ("partial","unavailable"):
            o=symmetric();o["obstacles"].update(coverage=coverage,items=[])
            r=evaluate(o);self.assertEqual(r["selected_action"],["wait",0])
            self.assertIsNone(r["sample"])
            self.assertTrue(all(x["final_total"] is None for x in r["directional_samples"]))

    def test_reference_renaming_and_order_do_not_choose_a_side(self):
        a=symmetric();b=deepcopy(a)
        for channel in ("food","obstacles"):
            b[channel]["items"][0]["ref"]="renamed"
        b["ground"]["samples"].reverse()
        self.assertEqual(evaluate(a)["directional_samples"],evaluate(b)["directional_samples"])

    def test_input_output_separation(self):
        o=symmetric();before=deepcopy(o);r=evaluate(o)
        r["observed_terrain"]["evidence"]["food"]["items"].clear()
        self.assertEqual(o,before)
        self.assertEqual(evaluate(o)["selected_action"],evaluate(before)["selected_action"])

    def test_frozen_local_episode_reuses_seed_then_expires(self):
        s=Session();values=[]
        for _ in range(4):
            s.apply(s.tied_packet());values.append(deepcopy(s.last()))
        self.assertEqual([x["episode_seq"] for x in values],[1,1,1,2])
        self.assertEqual([x["episode"]["uses"] for x in values],[1,2,3,1])
        self.assertEqual(len({x["evaluation"]["sample"]["seed"] for x in values[:3]}),1)
        self.assertEqual(values[-1]["closure_reason"],"capture_deadline")
        self.assertNotEqual(values[0]["evaluation"]["sample"]["seed"],values[-1]["evaluation"]["sample"]["seed"])

    def test_decision_budget_can_expire_before_capture_deadline(self):
        s=Session()
        for _ in range(3):s.apply(s.tied_packet())
        p=s.tied_packet();p["capture_us"]-=10000
        p["distant"]["capture_window"].update(start_us=p["capture_us"],end_us=p["capture_us"])
        p["movement_surface"]=surface(p,[item("o",2,0)])
        s.apply(p);self.assertEqual(s.last()["closure_reason"],"decision_budget")

    def test_priority_and_incomplete_close_episode_without_reroll(self):
        for kind in ("pickup","partial","missing_result"):
            s=Session();s.apply(s.tied_packet());p=s.tied_packet()
            if kind=="pickup":p["food"]["visible"]=[material()]
            elif kind=="partial":p["movement_surface"]["obstacles"].update(coverage="partial",items=[])
            else:s.loop.results.clear()
            s.multi.observe(p)
            self.assertIsNone(s.last()["episode"])
            self.assertEqual(s.last()["episode_seq"],1)
            self.assertIsNotNone(s.last()["closed_episode_ref"])

    def test_context_change_and_observation_gap_start_fresh_seed(self):
        for kind in ("food","gap"):
            s=Session();s.apply(s.tied_packet())
            if kind=="gap":s.seq+=1
            p=s.tied_packet()
            if kind=="food":p["food"]["visible"][0]["ref"]="replacement"
            s.apply(p)
            self.assertEqual(s.last()["episode_seq"],2)
            self.assertIn(s.last()["closure_reason"],("candidate_context_changed","observation_gap"))

    def test_result_translation_invalidates_the_old_local_episode(self):
        s=Session(seed=2)
        def p():
            value=s.packet()
            value["food"]["visible"]=[dict(material(distance=5),forward=5*cos(pi/8),right=5*sin(pi/8))]
            return value
        c,_=s.apply(p());self.assertEqual(c["kind"],"move")
        self.assertIsNotNone(s.last()["episode"])
        s.apply(p())
        self.assertEqual(s.last()["episode"]["uses"],1)
        self.assertEqual(s.last()["transition"],"started")
        self.assertEqual(s.last()["closure_reason"],"body_continuity_unavailable")
        self.assertEqual(s.last()["episode_seq"],2)

    def test_final_numerical_tie_uses_frozen_rank_not_direction_order(self):
        o=symmetric();draw=evaluate(o)["sample"]
        v={r["direction_deg"]:r for r in draw["vector"]}
        delta=v[-90]["perturbation"]-v[90]["perturbation"]
        row=o["ground"]["samples"][-1 if delta>0 else 0]
        row["height_delta"]=abs(delta)/2
        r=evaluate(o)
        self.assertEqual(r["final_minimum_directions"],[-90,90])
        self.assertEqual(r["selected_action"],["turn",min((-90,90),key=lambda a:v[a]["rank"])])

    def test_period_boundary_and_long_capture_gap_expire_the_episode(self):
        s=Session();s.seq=63;s.apply(s.tied_packet())
        self.assertEqual(s.last()["episode"]["expires_us"],16_000_000)
        s.apply(s.tied_packet())
        self.assertEqual(s.last()["closure_reason"],"capture_deadline")
        self.assertEqual(s.last()["episode_seq"],2)
        s.seq+=8;s.apply(s.tied_packet())
        self.assertEqual(s.last()["closure_reason"],"capture_deadline")
        self.assertEqual(s.last()["episode_seq"],3)

    def test_replay_concurrency_conflict_and_agent_isolation(self):
        s=Session();p=s.tied_packet();first=s.multi.observe(p);before=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            replies=list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(x["command"]==first["command"] and x["new_frames"]==0 for x in replies))
        self.assertEqual(before,s.multi.snapshot())
        changed=deepcopy(p);changed["food"]["visible"][0]["right"]+=.01
        with self.assertRaises(ValueError):s.multi.observe(changed)
        self.assertEqual(before,s.multi.snapshot())
        self.assertEqual(s.multi.agents["npc_b"].decisions,{})

    def test_rejected_sensory_admission_does_not_consume_episode_or_learning(self):
        from runtime.sensory_observation import SensoryObservationStore
        s=Session();p=s.tied_packet();before=s.multi.snapshot()
        with patch.object(SensoryObservationStore,"admit",side_effect=ValueError("injected")):
            with self.assertRaisesRegex(ValueError,"injected"):s.multi.observe(p)
        self.assertEqual(before,s.multi.snapshot())
        s.multi.observe(p);self.assertEqual(s.last()["episode_seq"],1)

    def test_configuration_is_explicit_frozen_atomic(self):
        s=Session();before=s.multi.snapshot();self.assertEqual(s.multi.configure(s.c)["tie_break_mode"],"frozen")
        for mode in ("disabled",None,False,"other"):
            c=dict(s.c,tie_break_mode=mode)
            with self.assertRaises(ValueError):s.multi.configure(c)
            self.assertEqual(before,s.multi.snapshot())
        loop=TieBreakResourceExploration("r",3);before=loop.snapshot()
        with self.assertRaises(ValueError):loop.configure(dict(s.c,run_id="wrong"))
        self.assertEqual(before,loop.snapshot())

    def test_mode_combinations_are_rejected_before_world_start(self):
        from integrations.luanti.tests.run_multi_resource import run
        for kw in (dict(steering=True),dict(lateral="neutral"),dict(lateral="left")):
            with self.assertRaisesRegex(ValueError,"tie break only"):
                run("natural_meadow",2,"mixed","unused",tie_break="frozen",**kw)

    def test_pickup_learning_and_variation_remain_the_same(self):
        a=Session(profile="restless");b=BaseSession()
        for s in (a,b):
            s.learn()
            for _ in range(3):s.apply(s.packet())
        self.assertEqual(a.loop.commands,b.loop.commands)
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.model.to_json(),b.loop.model.to_json())

    def test_disabled_replays_existing_real_commands_and_learning(self):
        matrix=json.loads(gzip.decompress((Path(__file__).parent/"fixtures/luanti_l15a_connection_replay.json.gz").read_bytes()))
        data=matrix["runs"][0]["data"];w=data["world"];loop=TieBreakResourceExploration(w["run_id"],2)
        for delivery in w["deliveries"]:
            p=deepcopy(delivery["request"]);kind=delivery["kind"]
            if kind=="configure":p.update(schema=SCHEMA,tie_break_mode="disabled")
            reply=getattr(loop,kind)(p)
            if kind=="observe":self.assertEqual(reply["command"],json.loads(delivery["response_wire"])["command"])
        for aid,a in loop.agents.items():
            prior=data["runtime"]["exploration"]["agents"][aid]
            self.assertEqual(a.learning,prior["learning"])
            self.assertEqual(a.snapshot()["active_model"],prior["active_model"])


class RealTieBreakTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.matrix=json.loads(gzip.decompress((Path(__file__).parent/
            "fixtures/luanti_l15a_tie_break_replay.json.gz").read_bytes()))

    def test_all_five_real_runs_replay_wire_geometry_state_and_dwell(self):
        from integrations.luanti.tests.check_terrain_tie_break import check
        from integrations.luanti.tests.check_terrain_lateral import decision_links
        self.assertEqual(len(self.matrix["runs"]),5)
        for run in self.matrix["runs"]:
            self.assertEqual(check(run["data"]),run["summary"])
            self.assertEqual(decision_links(run["data"]),run["decision_links"])
            for a in run["data"]["runtime"]["exploration"]["agents"].values():
                self.assertEqual(len(a["observations"]),128)
                self.assertEqual(len(a["results"]),128)

    def test_primary_no_improvement_and_forest_no_eligibility_are_preserved(self):
        runs=self.matrix["runs"]
        for start in (0,2):
            baseline,enabled=runs[start:start+2]
            self.assertEqual(baseline["summary"]["movement"],enabled["summary"]["movement"])
            self.assertEqual(baseline["summary"]["total_pickups"],0)
            self.assertEqual(enabled["summary"]["total_pickups"],0)
            for aid,a in enabled["summary"]["agents"].items():
                t=a["tie_break"]
                self.assertEqual(t["counts"]["changed_action"],0)
                self.assertEqual(t["dwell"]["final_position"],baseline["summary"]["agents"][aid]["tie_break"]["dwell"]["final_position"])
                if start==2:self.assertEqual(t["counts"]["eligible"],0)
        self.assertEqual(sum(a["tie_break"]["counts"]["applied"] for a in runs[1]["summary"]["agents"].values()),7)

    def test_response_loss_replay_keeps_seed_and_executes_once(self):
        run=self.matrix["runs"][4];world=run["data"]["world"];lost=world["guards"]["lost_tie"]
        a=run["data"]["runtime"]["exploration"]["agents"][lost["agent_id"]]
        requests=[d for d in world["deliveries"] if d["kind"]=="observe" and d["request"]["observation_id"]==lost["source_id"]]
        replies=[json.loads(d["response_wire"]) for d in requests]
        self.assertEqual(len(replies),2)
        self.assertEqual(replies[0]["command"],replies[1]["command"])
        self.assertEqual([r["new_frames"] for r in replies],[1,0])
        self.assertIsNotNone(a["decisions"][lost["source_id"]]["tie_break"]["evaluation"]["sample"])
        actions=[x for x in world["agents"][lost["agent_id"]]["actions"] if x["command"]["operation_id"]==lost["operation_id"]]
        self.assertEqual(len(actions),1);self.assertEqual(actions[0]["result"]["status"],"moved")
        self.assertTrue(all(world["guards"][k] for k in ("lost_response","loss_recovered","old_callback","duplicate_operation","cross_agent")))
