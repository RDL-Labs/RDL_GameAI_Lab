from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import unittest
from runtime.rest_reactivation import ReactivatingExploration, SCHEMA, retrieve, evaluate, project_reactivation
from test_movement_rest import Session as RestSession
from test_terrain_steering import food_packet
from test_resource_exploration import config
from runtime.terrain_resource_exploration import terrain_input
from runtime.subjective_movement_terrain import calculate_terrain


class Session(RestSession):
    def __init__(self, mode="enabled"):
        self.multi=ReactivatingExploration("r",3,assignment="steady")
        self.agent="npc_a";self.loop=self.multi.agents[self.agent]
        self.seq,self.revision,self.pose=0,0,"r:npc_a:pose:0"
        c=config();c.update(schema=SCHEMA,selection_profile="steady",rest_mode="fatigue",reactivation_mode=mode)
        self.multi.configure(c)


def blocked_memory():
    s=Session();p=food_packet(s);s.apply(p,"blocked");current=food_packet(s)
    records=[dict(observation=p,command=s.loop.commands[p["observation_id"]],result=s.loop.results["op:"+p["observation_id"]])]
    return s,records,current


class ReactivationTests(unittest.TestCase):
    def test_mode_switch_is_separate_from_rest_and_preserves_sampling(self):
        s=Session()
        for _ in range(10):s.apply(food_packet(s))
        ms=[d["reactivation"] for d in s.loop.decisions.values()]
        self.assertEqual([m["phase"] for m in ms], ["external_observation"]*4+["internal_reactivation"]*4+["resume_review","external_observation"])
        self.assertTrue(all(m["body_resting"] for m in ms[4:8]))
        self.assertFalse(ms[8]["body_resting"])
        self.assertEqual(ms[4]["bundle"],ms[8]["bundle"])
        self.assertIsNone(ms[9]["bundle"])
        self.assertEqual(s.multi.snapshot(),json.loads(json.dumps(s.multi.snapshot())))

    def test_disabled_preserves_rest_commands_learning_and_store(self):
        a=Session("disabled");b=RestSession()
        for _ in range(16):self.assertEqual(a.apply(food_packet(a)),b.apply(food_packet(b)))
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.store.snapshot(),b.loop.store.snapshot())

    def test_pickup_interrupt_discards_active_cache(self):
        s=Session()
        for _ in range(5):s.apply(food_packet(s))
        c,_=s.apply(s.packet());m=next(reversed(s.loop.decisions.values()))["reactivation"]
        self.assertEqual(c["kind"],"pickup");self.assertEqual(m["trigger"],"interrupted")
        self.assertEqual(m["phase"],"external_observation");self.assertIsNone(m["bundle"])

    def test_same_pose_blocked_episode_is_temporary_cost_not_a_model(self):
        s,records,p=blocked_memory();bundle=retrieve(records,p,None)
        state=s.multi.snapshot();e=evaluate(bundle,p,None)
        self.assertEqual(e["forward_penalty"],.5)
        self.assertEqual(e["model"]["status"],"no_adopted_model")
        self.assertEqual(s.multi.snapshot(),state)
        terrain=calculate_terrain(terrain_input(p,s.loop.teaching["appearance"]))
        for r in terrain["directional_samples"]:
            if r["status"]=="scored":r["total"]=0 if r["direction_deg"]==0 else .1 if r["direction_deg"]==45 else 1
        projected=project_reactivation(terrain,["move",1],e)
        self.assertTrue(projected["changed"]);self.assertEqual(projected["selected_action"],["turn",45])
        self.assertEqual(len(projected["contributions"][0]["operations"]),1)

    def test_pose_context_age_and_missing_information_prevent_projection(self):
        _,records,p=blocked_memory();b=retrieve(records,p,None)
        for cause in ("pose","view","age","missing"):
            q=deepcopy(p)
            if cause=="pose":q["pose_ref"]="other"
            elif cause=="view":q["food"]["visible"][0]["distance"]=7
            elif cause=="age":q["capture_us"]+=5000001
            else:q["food"]["coverage"]="partial"
            self.assertEqual(evaluate(b,q,None)["forward_penalty"],0)

    def test_success_is_kept_without_direction_generalization(self):
        s=Session();p=food_packet(s);s.apply(p)
        r=dict(observation=p,command=s.loop.commands[p["observation_id"]],result=s.loop.results["op:"+p["observation_id"]])
        q=food_packet(s);b=retrieve([r],q,None);e=evaluate(b,q,None)
        self.assertEqual(e["records"][0]["result_status"],"moved")
        self.assertEqual(e["forward_penalty"],0)

    def test_adopted_model_is_queried_with_original_scope_and_unchanged(self):
        s=Session();s.learn();self.assertIsNotNone(s.loop.model)
        p=s.packet();b=retrieve([],p,s.loop.model.model_ref);before=s.multi.snapshot()
        e=evaluate(b,p,s.loop.model)
        self.assertEqual(e["model"]["status"],"known")
        self.assertEqual(e["forward_penalty"],0)
        self.assertEqual(s.multi.snapshot(),before)
        q=food_packet(s)
        self.assertEqual(evaluate(b,q,s.loop.model)["model"]["status"],"unknown")
        self.assertEqual(evaluate(b,p,s.loop.model,True)["model"]["status"],"model_invalidated")
        self.assertEqual(evaluate(b,p,None)["model"]["status"],"model_changed")

    def test_budgets_cross_agent_future_and_duplicate_are_rejected(self):
        _,records,p=blocked_memory()
        with self.assertRaisesRegex(ValueError,"retrieval_budget"):retrieve(records*17,p,None)
        with self.assertRaisesRegex(ValueError,"retrieval_duplicate"):retrieve(records*2,p,None)
        for cause in ("agent","future"):
            rs=deepcopy(records)
            if cause=="agent":rs[0]["observation"]["agent_id"]="npc_b"
            else:rs[0]["result"]["executed_us"]=p["capture_us"]+1
            with self.assertRaises(ValueError):retrieve(rs,p,None)

    def test_replay_conflict_and_failed_admission_do_not_publish_partial_mode(self):
        s=Session()
        for _ in range(4):s.apply(food_packet(s))
        p=food_packet(s);s.multi.observe(p);state=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertEqual(s.multi.snapshot(),state)
        bad=deepcopy(p);bad["food"]["visible"][0]["appearance"]="changed"
        with self.assertRaises(ValueError):s.multi.observe(bad)
        self.assertEqual(s.multi.snapshot(),state)
        t=Session();t.apply(food_packet(t));bad=food_packet(t);before=t.multi.snapshot()
        bad["distant"]["payload"]["world_id"]="forbidden"
        with self.assertRaises(ValueError):t.multi.observe(bad)
        self.assertEqual(t.multi.snapshot(),before)

    def test_no_numeric_projection_into_missing_or_excluded_geometry(self):
        s,rs,p=blocked_memory();e=evaluate(retrieve(rs,p,None),p,None)
        t=calculate_terrain(terrain_input(p,s.loop.teaching["appearance"]))
        t["status"]="acquisition_incomplete"
        self.assertFalse(project_reactivation(t,["move",1],e)["applied"])
        t["status"]="complete"
        for r in t["directional_samples"]:
            if r["direction_deg"]==0:r["status"]="excluded_by_observation"
        self.assertFalse(project_reactivation(t,["move",1],e)["applied"])
        self.assertFalse(project_reactivation(t,["pickup",0],e)["applied"])

    def test_configuration_is_fixed_and_cache_cannot_cross_agents(self):
        s,rs,p=blocked_memory();before=s.multi.snapshot()
        c=config();c.update(schema=SCHEMA,selection_profile="steady",rest_mode="fatigue",reactivation_mode="disabled")
        with self.assertRaisesRegex(ValueError,"reactivation_configuration_conflict"):s.multi.configure(c)
        self.assertEqual(s.multi.snapshot(),before)
        b=retrieve(rs,p,None);q=deepcopy(p);q["agent_id"]="npc_b"
        with self.assertRaisesRegex(ValueError,"reactivation_binding"):evaluate(b,q,None)

    def test_retrieval_output_is_bounded_and_detached(self):
        _,rs,p=blocked_memory();many=[]
        for i in range(6):
            r=deepcopy(rs[0]);suffix=str(i)
            r["observation"]["observation_id"]+=suffix
            r["command"]["source_id"]+=suffix;r["command"]["operation_id"]+=suffix
            r["result"]["source_id"]+=suffix;r["result"]["operation_id"]+=suffix
            many.append(r)
        before=deepcopy(many);b=retrieve(many,p,None)
        self.assertEqual(b["scanned"],6);self.assertEqual(len(b["records"]),3)
        self.assertTrue(b["records"][0]["operation_id"].endswith("5"))
        b["records"][0]["observed"].clear()
        self.assertEqual(many,before)

    def test_actual_world_archive(self):
        path=Path(__file__).parent/"fixtures/luanti_l15a_rest_reactivation.json.gz"
        if not path.exists():self.skipTest("World archive not yet generated")
        from integrations.luanti.tests.check_rest_reactivation import check
        data=json.loads(gzip.decompress(path.read_bytes()));self.assertEqual(len(data["runs"]),3)
        for r in data["runs"]:
            self.assertEqual(check(r["data"]),r["summary"])
            if any(a["reactivation"]["changes"] for a in r["summary"]["agents"].values()):continue
            from runtime.movement_rest import RestResourceExploration, SCHEMA as REST
            state=r["data"]["runtime"]["exploration"]
            loop=RestResourceExploration(state["run_id"],state["periods"],state["seed"],state["assignment"])
            for delivery in r["data"]["world"]["deliveries"]:
                value=deepcopy(delivery["request"])
                if delivery["kind"]=="configure":value.pop("reactivation_mode");value["schema"]=REST
                response=getattr(loop,delivery["kind"])(value)
                if delivery["kind"]=="observe":self.assertEqual(response,json.loads(delivery["response_wire"]))
            baseline=loop.snapshot()
            for aid,a in state["agents"].items():
                for key in ("learning","active_model","sensory","commands","results"):
                    self.assertEqual(a[key],baseline["agents"][aid][key])
