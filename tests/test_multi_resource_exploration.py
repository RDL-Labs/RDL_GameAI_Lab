from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import unittest

from runtime.multi_resource_exploration import MultiResourceExploration, SCHEMA
from runtime.harvest_predictability import tendency, affordance, build_admission, section
from test_resource_exploration import Session as ResourceSession, config, material, feature
from test_exploration import result


class Session(ResourceSession):
    def __init__(self, profile="restless", agent="npc_a"):
        self.multi = MultiResourceExploration("r", 3)
        self.agent = agent
        self.loop = self.multi.agents[agent]
        self.loop.profile = profile
        self.seq,self.revision,self.pose = 0,0,f"r:{agent}:pose:0"
        c = config(); c.update(schema=SCHEMA,agent_id=agent,selection_profile=profile)
        self.multi.configure(c)

    def packet(self, food=True, complete=True):
        p=super().packet([feature()])
        p.update(agent_id=self.agent,observation_id=f"r:{self.agent}:obs:{self.seq}",pose_ref=self.pose)
        p["distant"].update(agent_id=self.agent,frame_id=f"r:{self.agent}:frame:{self.seq}",observer_frame_ref=self.pose)
        p["food"]["visible"]=[material()] if food else []
        if not complete:p["food"]["coverage"]="partial"
        return p

    def apply(self,p,status=None):
        c=self.multi.observe(p)["command"]
        r=result(c,status or dict(move="moved",turn="turned",wait="waited",pickup="picked_up")[c["kind"]]);r["up"]=0
        self.revision=r["after_revision"];self.pose=f"r:{self.agent}:pose:{self.revision}"
        r["after_pose_ref"]=self.pose
        self.multi.result(r);self.seq+=1
        return c,r

    def learn(self):
        self.apply(self.packet(False))
        for _ in range(6):self.apply(self.packet())
        return self.loop.learning["admission"]


class MultiResourceTests(unittest.TestCase):
    def test_real_t1_admission_then_frozen_model_prediction(self):
        s=Session();a=s.learn()
        self.assertEqual(a["status"],"ADOPTED")
        self.assertEqual((a["candidate"]["support_count"],a["candidate"]["validation_count"]),(3,2))
        self.assertEqual(len(a["canonical"]["model_cutover"]["records"]),1)
        self.assertEqual(len({r["operation_id"] for r in a["records"]}),5)
        self.assertIsNotNone(next(reversed(s.loop.decisions.values()))["harvest_prediction"])

    def test_identical_history_different_tendencies_success_can_start_exploration(self):
        sessions=[Session(p) for p in ("steady","curious","restless")]
        for s in sessions:s.learn()
        self.assertEqual(sessions[0].loop.learning["admission"]["records"],sessions[2].loop.learning["admission"]["records"])
        self.assertEqual(sessions[0].loop.model.model_ref,sessions[2].loop.model.model_ref)
        for _ in range(3):
            for s in sessions:s.apply(s.packet())
        a,b,c=[next(reversed(s.loop.decisions.values())) for s in sessions]
        self.assertEqual(a["action"][0],"pickup");self.assertEqual(b["action"][0],"pickup")
        self.assertTrue(c["exploration_started"]);self.assertTrue(c["reason"].startswith("variation_"))
        self.assertTrue(all(v["confirmed"] for v in sessions[2].loop.learning["comparisons"]))
        self.assertTrue(c["counterfactual"]["restless"]["request_exploration"])
        self.assertFalse(c["counterfactual"]["steady"]["request_exploration"])

    def test_boredom_is_not_canonical_difference(self):
        s=Session();s.learn();before=deepcopy(s.loop.learning["admission"]["canonical"])
        for _ in range(3):s.apply(s.packet())
        self.assertEqual(before,s.loop.learning["admission"]["canonical"])
        self.assertEqual(s.loop.learning["comparisons"][-1]["prediction_difference"],dict(acquired=0,affordance_persists=0))
        self.assertEqual(next(reversed(s.loop.decisions.values()))["variation"]["stimulation_difference"],1)

    def test_missing_or_unexecuted_not_predictable(self):
        s=Session();s.learn();s.apply(s.packet(complete=False))
        self.assertEqual(s.loop.learning["confirmations"],0)
        self.assertIsNone(next(reversed(s.loop.decisions.values()))["harvest_prediction"])

    def test_counterexample_invalidates_instead_of_boredom(self):
        s=Session();s.learn();s.apply(s.packet(False))
        self.assertTrue(s.loop.learning["invalidated"])
        self.assertEqual(s.loop.learning["confirmations"],0)
        self.assertIsNotNone(s.loop.model)
        s.apply(s.packet());self.assertIsNone(next(reversed(s.loop.decisions.values()))["harvest_prediction"])

    def test_formation_and_validation_failure_never_selected_away(self):
        s=Session();s.apply(s.packet(False))
        for i in range(6):s.apply(s.packet(),"not_found" if i==3 else None)
        self.assertEqual(s.loop.learning["admission"]["status"],"REJECT")
        self.assertIsNone(s.loop.model)

    def test_no_observed_count_change_no_fabricated_rupture(self):
        s=Session()
        for _ in range(7):s.apply(s.packet())
        self.assertEqual(s.loop.learning["admission"]["status"],"DEFER")
        self.assertIsNone(s.loop.model)

    def test_replay_concurrent_does_not_grow_learning(self):
        s=Session();s.learn();p=s.packet();s.multi.observe(p);before=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            receipts=list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(r["new_frames"]==0 for r in receipts))
        self.assertEqual(s.multi.snapshot(),before)

    def test_agent_state_and_forged_reference_isolation(self):
        s=Session();before=s.multi.agents["npc_b"].snapshot();s.learn()
        self.assertEqual(s.multi.agents["npc_b"].snapshot(),before)
        p=s.packet();p["agent_id"]="npc_b"
        with self.assertRaisesRegex(ValueError,"cross_agent_reference"):s.multi.observe(p)
        self.assertEqual(s.multi.agents["npc_b"].snapshot(),before)

    def test_failed_sensor_admission_publishes_no_learning(self):
        s=Session();s.apply(s.packet(False))
        for _ in range(5):s.apply(s.packet())
        before=s.multi.snapshot();p=s.packet();p["distant"]["agent_id"]="npc_b"
        with self.assertRaises(ValueError):s.multi.observe(p)
        self.assertEqual(s.multi.snapshot(),before)

    def test_profile_frozen_and_legacy_configuration_refused(self):
        s=Session();before=s.multi.snapshot();c=config();c.update(schema=SCHEMA,selection_profile="steady")
        with self.assertRaises(ValueError):s.multi.configure(c)
        self.assertEqual(s.multi.snapshot(),before)
        with self.assertRaises(ValueError):s.multi.configure(config())

    def test_model_agent_and_run_scope(self):
        s=Session();s.learn()
        with self.assertRaises(ValueError):s.loop.model.interpret_harvest_pattern(section("r","npc_b","before",False,True))
        self.assertEqual(s.loop.model.interpret_harvest_pattern(section("other","npc_a","before",False,True))["status"],"unknown")

    def test_tendency_boundaries(self):
        self.assertFalse(tendency("restless",2)["request_exploration"])
        self.assertTrue(tendency("restless",3)["request_exploration"])
        self.assertFalse(tendency("curious",5)["request_exploration"])
        self.assertTrue(tendency("curious",6)["request_exploration"])
        self.assertFalse(tendency("steady",100)["request_exploration"])

    def test_three_agent_roles_and_swapped_assignment(self):
        a=MultiResourceExploration("x");b=MultiResourceExploration("x",assignment="swapped")
        self.assertEqual([v.profile for v in a.agents.values()],["steady","curious","restless"])
        self.assertEqual([v.profile for v in b.agents.values()],["restless","curious","steady"])

    def test_each_agent_can_learn_only_its_own_model(self):
        models=[]
        for agent in ("npc_a","npc_b","npc_c"):
            s=Session(agent=agent);s.learn()
            self.assertEqual(s.loop.model.agent_id,agent)
            self.assertTrue(all(r["agent_id"]==agent for r in s.loop.learning["records"]))
            models.append(s.loop.model.model_ref)
        self.assertEqual(len(set(models)),3)

    def test_cross_agent_frame_and_operation_rejected_before_mutation(self):
        s=Session();p=s.packet();p["distant"]["frame_id"]="r:npc_b:frame:0"
        before=s.multi.snapshot()
        with self.assertRaisesRegex(ValueError,"cross_agent_frame"):s.multi.observe(p)
        self.assertEqual(before,s.multi.snapshot())
        c,r=s.apply(s.packet());r["operation_id"]="op:r:npc_b:obs:0"
        before=s.multi.snapshot()
        with self.assertRaisesRegex(ValueError,"cross_agent_operation"):s.multi.result(r)
        self.assertEqual(before,s.multi.snapshot())

    def test_unexecuted_pickup_does_not_support_model(self):
        s=Session();s.apply(s.packet(False))
        for _ in range(3):s.apply(s.packet())
        p=s.packet();c=s.multi.observe(p)["command"]
        r=result(c,"expired");r.update(up=0,executed_us=c["expires_us"],after_pose_ref=s.pose)
        s.multi.result(r);s.seq+=2;s.apply(s.packet())
        self.assertEqual(len(s.loop.learning["records"]),3)
        self.assertIsNone(s.loop.model)

    def test_variation_does_not_create_extra_action_budget(self):
        s=Session();s.learn()
        for _ in range(25):s.apply(s.packet())
        self.assertEqual(len(s.loop.observations),len(s.loop.results))
        self.assertEqual(len(s.loop.commands),len(s.loop.observations))
        for p in s.loop.observations.values():
            self.assertLessEqual(s.loop.commands[p["observation_id"]]["expires_us"],(p["capture_us"]//16_000_000+1)*16_000_000)


class RealMultiResourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=Path(__file__).parent/"fixtures/luanti_l14b_replay.json.gz"
        cls.matrix=json.loads(gzip.decompress(path.read_bytes()))

    def test_every_accepted_wire_replays_and_shared_stock_is_conserved(self):
        from integrations.luanti.tests.check_multi_resource import check
        self.assertEqual(len(self.matrix["runs"]),3)
        for run in self.matrix["runs"]:
            self.assertEqual(check(run["data"]),run["summary"])

    def test_rich_resource_world_predictable_success_can_request_exploration(self):
        main=[r for r in self.matrix["runs"] if r["summary"]["periods"]==30]
        self.assertEqual([r["summary"]["assignment"] for r in main],["mixed","swapped"])
        departures=[]
        for run in main:
            for agent,a in run["summary"]["agents"].items():
                if a["profile"]=="steady":self.assertEqual(a["exploration_requests"],0)
                departures.extend(a["departures"])
            self.assertEqual(sum(a["pickups"] for a in run["summary"]["agents"].values())+run["summary"]["remaining"],96)
        self.assertTrue(any(d["available_observed_stock"]>0 and d["first_action_status"] in ("moved","turned") for d in departures))

    def test_excluded_attempts_are_not_counted_as_acceptance(self):
        excluded=self.matrix["excluded_attempts"]
        self.assertEqual(len(excluded),3)
        self.assertTrue(all(not r["acceptance"] for r in excluded))
        self.assertTrue(excluded[0]["data"]["world"]["failure"])
        self.assertTrue(excluded[1]["data"]["world"]["failure"])
        self.assertFalse(excluded[2]["data"]["world"].get("failure"))
        from integrations.luanti.tests.check_resource_exploration import check
        legacy=self.matrix["legacy_regression"]
        self.assertEqual(check(legacy["data"]),legacy["summary"])
        self.assertTrue(legacy["data"]["world"]["loss_recovered"])


if __name__=="__main__":unittest.main()
