"""Synthetic body/observation controls; real evidence replay is separate."""
from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from runtime.learned_exploration import LearnedExplorationSeries, LearnedExplorationDay, observation_key, bootstrap, inspect_day
from runtime.exploration_series import digest
from runtime.exploration import SCHEMA
from test_exploration import packet, result


def day(s, name, found=3, partial=False, mismatch=False):
    start=s.start_day(dict(episode_id=name, run_id=name))
    loop=s.loop
    loop.configure(dict(schema=SCHEMA, run_id=name, world_epoch=1, agent_id="npc_a",clock_id="world-sim-v1"))
    revision=0; pose=name+":pose:0"
    for i in range(6):
        p=packet(i,name); p["observation_id"]=name+f":obs:{i}"; p["distant"]["frame_id"]=name+f":d:{i}"
        p["body_revision"]=revision; p["pose_ref"]=pose; p["distant"]["observer_frame_ref"]=pose
        if found is not None and i>=found:
            p["food"]["visible"]=[dict(ref=name+":food",distance=5,forward=5,right=0)]
        if partial:
            p["ground"]["coverage"]="partial";p["ground"]["cells"][0].update(color="unknown",status="unloaded")
        if mismatch and i==1:
            p["ground"]["cells"][0]["color"]="blue"
        c=loop.observe(p)["command"]
        r=result(c,{"move":"moved","turn":"turned","wait":"waited","pickup":"picked_up"}[c["kind"]])
        revision=r["after_revision"];pose=name+f":pose:{revision}"
        r["after_pose_ref"]=pose
        loop.result(r)
    loop.finish(dict(run_id=name, world_epoch=1, agent_id="npc_a",ended_us=16000000,reason="time_limit"))
    request=dict(**start["request"],state_digest=digest(loop.snapshot()))
    return request, s.close_day(request)


class LearnedExplorationTests(unittest.TestCase):
    def test_three_distinct_discovery_days_stop_and_replay(self):
        s=LearnedExplorationSeries("s","record")
        requests=[]
        for n,found in enumerate((3,None,3,3)):
            req,r=day(s,f"day-{n}",found);requests.append(req)
            self.assertEqual(s.close_day(req),r)
            self.assertEqual(s.summary()["discovery_count"],(1,1,2,3)[n])
        self.assertEqual(s.summary()["status"],"discovery_target_reached")
        self.assertEqual([d["day"] for d in s.summary()["discoveries"]],[1,3,4])
        with self.assertRaisesRegex(ValueError,"closed"):s.start_day(dict(episode_id="extra",run_id="extra"))
        self.assertEqual(s.close_day(requests[0])["metrics"]["first_food_us"],770000)

    def test_thirty_day_boundary_preserves_partial_counts(self):
        for count in (0,1,2,3):
            s=LearnedExplorationSeries("s","record")
            for n in range(30):
                day(s,f"d-{n}",3 if n>=30-count else None)
            self.assertEqual(s.summary()["discovery_count"],count)
            self.assertEqual(s.summary()["status"],"discovery_target_reached" if count==3 else "discovery_target_unmet_at_limit")
            self.assertEqual(sum(d is None for d in s.summary()["discoveries"]),3-count)
            with self.assertRaisesRegex(ValueError,"closed"):s.start_day(dict(episode_id="31",run_id="31"))

    def test_sleep_probe_then_real_t1_cutover_then_model_use(self):
        s=LearnedExplorationSeries("s")
        _,r=day(s,"formation")
        self.assertEqual(r["sleep"]["formation_support"],1)
        self.assertIsNone(s.learning)
        _,r=day(s,"validation")
        self.assertEqual(s.inspection["disposition"],"RETAIN")
        self.assertEqual(s.inspection["validation_count"],1)
        self.assertIsNotNone(s.learning["cutover"])
        self.assertTrue(all(d["reason"] != "active_M_B" for d in s.days[1]["state"]["decisions"].values()))
        parent=s.days[0]["state"]["model"]["model_ref"]
        day(s,"use")
        first=next(iter(s.days[2]["state"]["decisions"].values()))
        self.assertEqual(first["reason"],"active_M_B")
        self.assertNotEqual(parent,first["prediction"]["model_ref"])
        self.assertEqual(s.canonical.snapshot()["model_archive"][parent]["adopted_relations"],[])

    def test_adoption_controls_same_materials_and_draws(self):
        series=[]
        for mode in ("inspect","adopt"):
            s=LearnedExplorationSeries("same",mode)
            day(s,"formation");day(s,"validation");day(s,"use")
            series.append(s)
        a,b=series
        self.assertEqual(a.candidate,b.candidate)
        self.assertEqual(a.inspection,b.inspection)
        self.assertEqual(a.learning["artifact"],b.learning["artifact"])
        self.assertEqual(a.days[2]["state"]["tape"],b.days[2]["state"]["tape"])
        self.assertIsNone(a.learning["cutover"])
        ds=[next(iter(s.days[2]["state"]["decisions"].values())) for s in series]
        self.assertEqual(ds[0]["prediction"]["status"],"unknown")
        self.assertEqual(ds[1]["prediction"]["status"],"known")
        self.assertNotEqual(ds[0]["action"],ds[1]["action"])

    def test_counterexample_rejects_and_does_not_activate(self):
        s=LearnedExplorationSeries("s");day(s,"formation");day(s,"empty",None)
        self.assertEqual(s.inspection["disposition"],"REJECT")
        self.assertIsNone(s.learning)
        day(s,"later",None)
        self.assertTrue(all(d["reason"] != "active_M_B" for d in s.loop.decisions.values()))

    def test_mismatch_and_partial_are_defer_not_negative(self):
        for kw in (dict(mismatch=True),dict(partial=True)):
            s=LearnedExplorationSeries("s");day(s,"formation");day(s,"validation",**kw)
            self.assertEqual(s.inspection["disposition"],"DEFER")
            self.assertIsNone(s.learning)

    def test_no_eligible_route_is_not_food_absence(self):
        s=LearnedExplorationSeries("s",max_days=1)
        day(s,"partial",found=3,partial=True)
        self.assertEqual(s.summary()["discovery_count"],1)
        self.assertIsNone(s.candidate)
        self.assertEqual(s.days[0]["receipt"]["sleep"]["status"],"no_eligible_discovery_route")

    def test_alias_run_and_changed_day_reject(self):
        s=LearnedExplorationSeries("s");req,_=day(s,"one")
        with self.assertRaisesRegex(ValueError,"conflict"):s.close_day(dict(req,state_digest="wrong"))
        with self.assertRaisesRegex(ValueError,"reused"):s.start_day(dict(episode_id="two",run_id="one"))
        state=deepcopy(s.days[0]["state"]);state["probe"]=s.candidate
        with self.assertRaisesRegex(ValueError,"alias"):inspect_day(s.candidate,state,"one")

    def test_concurrent_close_is_once_and_old_receipt_preserves_pending(self):
        s=LearnedExplorationSeries("s");req,r=day(s,"one")
        with ThreadPoolExecutor(4) as pool:
            self.assertEqual(list(pool.map(s.close_day,[req]*8)),[r]*8)
        start=s.start_day(dict(episode_id="two",run_id="two"))
        s.close_day(req)
        self.assertEqual(s.pending,start)
        self.assertEqual(len(s.days),1)

    def test_close_atomic_failure_does_not_publish_t1_or_day(self):
        s=LearnedExplorationSeries("s");day(s,"formation")
        before=s.snapshot()
        with patch('runtime.learned_exploration.canonical_state',side_effect=ValueError("injected")):
            with self.assertRaisesRegex(ValueError,"injected"):day(s,"validation")
        self.assertEqual(s.days,before["days"])
        self.assertEqual(s.canonical.snapshot(),before["canonical"])
        self.assertIsNone(s.inspection)
        request=dict(**s.pending["request"],state_digest=digest(s.loop.snapshot()))
        s.close_day(request)
        self.assertIsNotNone(s.learning["cutover"])

    def test_observation_atomic_and_immutable_replay(self):
        loop=LearnedExplorationDay("r","s",1,1)
        loop.configure(dict(schema=SCHEMA,run_id="r",world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1"))
        p=packet(run="r");before=loop.snapshot()
        bad=deepcopy(p);bad["distant"]["payload"]["world_id"]="hidden"
        with self.assertRaises(ValueError):loop.observe(bad)
        self.assertEqual(before,loop.snapshot())
        r=loop.observe(p);again=loop.observe(p)
        self.assertEqual(again["new_frames"],0)
        self.assertEqual(r["command"],again["command"])
        self.assertEqual(len(loop.decisions),1)
        changed=deepcopy(p);changed["food"]["coverage"]="partial"
        with self.assertRaisesRegex(ValueError,"conflict"):loop.observe(changed)

    def test_sampler_has_no_color_day_name_or_hidden_path_input(self):
        self.assertEqual(bootstrap(99),bootstrap(99))
        self.assertEqual(len(bootstrap(99)[0]),64)
        actions=[]
        for color,run in (("gray","day99"),("blue","success")):
            loop=LearnedExplorationDay(run,"s",1,99)
            loop.configure(dict(schema=SCHEMA,run_id=run,world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1"))
            p=packet(run=run)
            for c in p["ground"]["cells"]:c["color"]=color
            r=loop.observe(p)["command"];actions.append((r["kind"],r["amount"]))
        self.assertEqual(*actions)

    def test_no_world_or_feature_identity_in_comparison(self):
        p=packet();self.assertIsNotNone(observation_key(p))
        p["distant"]["payload"]["features"]=[dict(feature_id="f0",color_band="muted_red",azimuth_interval_deg=[0,5],elevation_interval_deg=[0,5])]
        first=observation_key(p);p["distant"]["payload"]["features"][0]["feature_id"]="different"
        self.assertEqual(observation_key(p),first)
        p["distant"]["coverage"]="PARTIAL"
        self.assertIsNone(observation_key(p))

    def test_abort_does_not_become_normal_success_and_keeps_discovery(self):
        s=LearnedExplorationSeries("s");day(s,"one")
        s.start_day(dict(episode_id="two",run_id="two"));s.abort("world_or_transport_error")
        self.assertEqual(s.summary()["status"],"mechanism_error")
        self.assertEqual(s.summary()["discovery_count"],1)
        self.assertIsNotNone(s.pending)

    def test_output_mutation_cannot_change_adopted_inputs(self):
        s=LearnedExplorationSeries("s");day(s,"one");day(s,"two")
        snap=s.snapshot();snap["candidate"]["common_relation_signature"]["trace"].clear()
        self.assertTrue(s.candidate["common_relation_signature"]["trace"])
        self.assertTrue(s.canonical.model_for_agent("npc_a").adopted_relations)

    def test_http_isolated_methods_validation_and_replay(self):
        from http.server import ThreadingHTTPServer
        from threading import Thread
        from urllib.request import Request, urlopen
        from urllib.error import HTTPError
        from runtime.learned_exploration_http import LearnedExplorationHandler
        s=LearnedExplorationSeries("s");s.start_day(dict(episode_id="e",run_id="r"))
        server=ThreadingHTTPServer(("127.0.0.1",0),LearnedExplorationHandler);server.series=s
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        def post(name,value):
            with urlopen(Request(f"http://127.0.0.1:{server.server_port}/v1/exploration/{name}",
                json.dumps(value).encode(),{"Content-Type":"application/json"}),timeout=2) as r:
                return json.load(r)
        try:
            with self.assertRaises(HTTPError) as e:post("learn",{})
            self.assertEqual(e.exception.code,404);e.exception.close()
            post("configure",dict(schema=SCHEMA,run_id="r",world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1"))
            before=s.loop.snapshot()
            bad=packet(run="r");bad["destination"]=[0,26]
            with self.assertRaises(HTTPError) as e:post("observe",bad)
            self.assertEqual(e.exception.code,422);e.exception.close()
            self.assertEqual(s.loop.snapshot(),before)
            self.assertEqual(post("observe",packet(run="r"))["new_frames"],1)
            self.assertEqual(post("observe",packet(run="r"))["new_frames"],0)
        finally:
            server.shutdown();server.server_close();thread.join()

    def test_adopted_route_aborts_on_new_observation_without_rewriting_model(self):
        s=LearnedExplorationSeries("s");day(s,"formation");day(s,"validation")
        model=s.canonical.model_for_agent("npc_a").to_json()
        day(s,"changed",mismatch=True)
        ds=list(s.loop.decisions.values())
        self.assertEqual(ds[0]["reason"],"active_M_B")
        self.assertTrue(all(d["route_status"]=="aborted" for d in ds[1:]))
        self.assertTrue(all(d["reason"]!="active_M_B" for d in ds[1:]))
        self.assertEqual(s.canonical.model_for_agent("npc_a").to_json(),model)

    def test_validation_body_gap_is_defer(self):
        s=LearnedExplorationSeries("s");day(s,"formation")
        candidate=deepcopy(s.candidate)
        candidate["common_relation_signature"]["trace"][0]["result_status"]="blocked"
        # Only an internal test injection. No public HTTP accepts candidate payloads.
        s.candidate=candidate
        day(s,"validation")
        self.assertEqual(s.inspection["disposition"],"DEFER")
        self.assertIsNone(s.learning)

    def test_real_replay(self):
        path=Path(__file__).parent/"fixtures/luanti_l13s_replay.json.gz"
        from integrations.luanti.tests.check_learned_exploration import check_matrix
        a=json.loads(gzip.decompress(path.read_bytes()))
        summaries=check_matrix(a)
        from integrations.luanti.tests.check_learned_exploration import check_series
        from integrations.luanti.tests.branch_learned_exploration import compare
        check_series(a["shared_history_control"])
        source=next(s for s in a["series"] if s["config"]["mode"]=="adopt")
        self.assertEqual(compare(source,a["shared_history_control"]),a["shared_history_control"]["comparison"])
        self.assertEqual({s["config"]["mode"] for s in summaries},{"record","inspect","adopt"})
        self.assertTrue(next(s for s in summaries if s["config"]["mode"]=="adopt")["adopted"])

    def test_real_learned_transport_faults(self):
        from integrations.luanti.tests.check_learned_exploration import check_matrix
        path=Path(__file__).parent/"fixtures/luanti_l13s_replay.json.gz"
        a=json.loads(gzip.decompress(path.read_bytes()))
        check_matrix(a["faults"])
        from integrations.luanti.tests.check_exploration import check
        check(a["legacy_regression"]["data"])
        w=a["faults"]["series"][0]["days"][0]["data"]["world"]
        self.assertTrue(w["lost_response"] and w["loss_recovered"])
        self.assertTrue(w["guards"]["old_callback"])

if __name__=="__main__":unittest.main()
