import copy
import json
from concurrent.futures import ThreadPoolExecutor
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from runtime.boundary_defense import BoundaryDefense, SCHEMA, LIMITATION, UNIT, reaction_step
from runtime.bridge import BridgeHandler, run as run_bridge


def config(inclusion=0, threshold=3, defender="A", actor="B"):
    return {"schema": SCHEMA, "run_id": "run", "world_epoch": 1, "defender": defender, "actor": actor,
            "site_ref": "site", "clock_id": "clock", "registration": {"source": "fixture", "unit_refs": [f"unit-{i}" for i in range(1,9)]},
            "profile": {"id": "fixture-life-sensory", "revision": 1, "radius": 12},
            "reaction": {"profile_id": "label", "source": "fixture", "base_threshold": threshold},
            "relation": {"relation_id": "relation", "source": "fixture", "action": "observed_unit_taken", "beneficiary_inclusion": inclusion},
            "site_relation": {"source": "fixture", "continued_use": True}}


def request(c, seq=1, capture=100):
    n = {k: c[k] for k in ("run_id", "world_epoch", "defender", "actor", "site_ref", "clock_id")}
    n.update(notice_id=f"notice-{seq}", event_id=f"event-{seq}", unit_ref=f"unit-{seq}", capture_us=capture, seq=seq,
             profile=copy.deepcopy(c["profile"]), pose_ref="pose", before_id=f"before-{seq}", after_id=f"after-{seq}",
             action="observed_unit_taken", units=1, coverage="complete", limitations=LIMITATION)
    def packet(side, order):
        visible = [{"ref": c["actor"], "kind": "npc", "distance": 2, "relative_position": {"x": 2, "y": 0, "z": 0}}]
        if side == "before": visible.append(dict(copy.deepcopy(visible[0]), ref=n["unit_ref"], kind="food"))
        return {"packet_id": n[side+"_id"], "observer": c["defender"], "capture_us": capture, "seq": seq,
                "order": order, "pose_ref": n["pose_ref"], "profile": copy.deepcopy(c["profile"]), "coverage": "complete", "visible": visible}
    effect = {k: n[k] for k in ("event_id", "actor", "site_ref", "unit_ref", "capture_us", "seq", "action", "units")}
    effect.update(order=2, established=True, source=LIMITATION)
    return {"now_us": capture, "record": {"notice": n, "before": packet("before",1), "effect": effect, "after": packet("after",3)}}


def setup(**kwargs):
    c = config(**kwargs)
    b = BoundaryDefense(c["run_id"])
    b.configure(c)
    return b, c


class BoundaryDefenseTests(unittest.TestCase):
    def unchanged_rejection(self, b, req, reason):
        before = b.snapshot()
        with self.assertRaisesRegex(ValueError, reason): b.observe(req)
        self.assertEqual(b.snapshot(), before)

    def test_matrix_and_both_roles(self):
        for defender, actor in (("A","B"),("B","A")):
            for inc in (0,1):
                for threshold in (3,9):
                    for times in ((0,), (0,250000,500000), (0,5000000,10000000)):
                        b,c = setup(inclusion=inc, threshold=threshold, defender=defender, actor=actor)
                        outputs = [b.observe(request(c,i+1,t))["receipt"] for i,t in enumerate(times)]
                        first = next((i+1 for i,r in enumerate(outputs) if r["permit"]), None)
                        expected = 1 if threshold+8*inc==3 else (3 if len(times)==3 and times[-1]==500000 and threshold+8*inc in (9,11) else None)
                        self.assertEqual(first, expected)
                        self.assertTrue(all(r["evaluation"]["appraisal_increment"] == 4*UNIT for r in outputs))
                        self.assertEqual(outputs[-1]["evaluation"]["load_after"], 11500000 if times[-1]==500000 else 4*UNIT)

    def test_equality_zero_decay_and_jitter(self):
        self.assertTrue(reaction_step(7*UNIT,0,11*UNIT)["threshold_reached"])
        self.assertEqual(reaction_step(4*UNIT,5*UNIT,17*UNIT)["load_before"],0)
        for delay1 in (0,249999):
            for delay2 in (0,249999):
                for delay3 in (0,249999):
                    for spacing in (250000,5000000):
                        b,c=setup(inclusion=1)
                        out=[b.observe(request(c,i+1,i*spacing+delay))["receipt"] for i,delay in enumerate((delay1,delay2,delay3))]
                        self.assertEqual(out[-1]["permit"] is not None,spacing==250000)

    def test_relation_changes_only_threshold(self):
        histories=[]
        for inc in (0,1):
            b,c=setup(inclusion=inc)
            histories.append([b.observe(request(c,i+1,i*250000))["receipt"]["evaluation"] for i in range(3)])
        for x,y in zip(*histories):
            for key in ("load_before","load_after","appraisal_increment","elapsed_us","decay"):
                self.assertEqual(x[key],y[key])
            self.assertEqual(y["warning_threshold"]-x["warning_threshold"],8*UNIT)

    def test_unavailable_is_not_zero_or_quiet(self):
        for mutation,reason in (
            (lambda r:r["record"].update(before=None),"source_missing"),
            (lambda r:r["record"]["notice"].update(coverage="partial"),"acquisition_incomplete"),
            (lambda r:r["record"]["after"].update(coverage="partial"),"acquisition_incomplete"),
            (lambda r:r["record"]["before"].update(visible=[]),"actor_not_visible"),
            (lambda r:r["record"]["effect"].update(established=False),"pickup_not_established"),
        ):
            b,c=setup();r=request(c);mutation(r);v=b.observe(r)["receipt"]
            self.assertEqual(v["status"],"unavailable");self.assertIn(reason,v["reasons"])
            self.assertIsNone(v["evaluation"]);self.assertIsNone(v["permit"]);self.assertEqual(b.snapshot()["load"],0)

    def test_unregistered_relation_and_unit(self):
        for missing in ("relation","unit"):
            c=config()
            if missing=="relation": c["relation"]=None
            else: c["registration"]["unit_refs"].remove("unit-1")
            b=BoundaryDefense("run");b.configure(c)
            v=b.observe(request(c))["receipt"]
            self.assertEqual(v["reasons"],["relation_unconfigured" if missing=="relation" else "reference_unregistered"])

    def test_unavailable_does_not_pause_decay(self):
        b,c=setup();b.observe(request(c,1,0))
        r=request(c,2,3*UNIT);r["record"]["notice"]["coverage"]="partial";b.observe(r)
        v=b.observe(request(c,3,5*UNIT))["receipt"]["evaluation"]
        self.assertEqual(v["elapsed_us"],5*UNIT);self.assertEqual(v["load_before"],0)

    def test_response_loss_replay_keeps_receipt_after_deadline(self):
        b,c=setup();r=request(c);first=b.observe(r);state=b.snapshot();r["now_us"]=20*UNIT
        again=b.observe(r)
        self.assertFalse(again["new_event"]);self.assertEqual(first["receipt"],again["receipt"])
        self.assertEqual(state,b.snapshot())

    def test_conflicting_notice_and_scope_are_atomic(self):
        b,c=setup();r=request(c);b.observe(r)
        changed=copy.deepcopy(r);changed["record"]["notice"]["coverage"]="partial"
        self.unchanged_rejection(b,changed,"notice_conflict")
        for key in ("run_id","world_epoch","defender","actor","site_ref","clock_id"):
            changed=copy.deepcopy(r);changed["record"]["notice"][key]="foreign"
            self.unchanged_rejection(b,changed,"notice_scope")

    def test_source_alias_does_not_create_second_vote(self):
        for key in ("event_id","unit_ref","seq","before_id","after_id"):
            b,c=setup();b.observe(request(c));r=request(c,2,200)
            old=request(c)["record"]["notice"][key]
            r["record"]["notice"][key]=old
            if key in ("event_id","unit_ref","seq"): r["record"]["effect"][key]=old
            if key=="seq":
                for side in ("before","after"):r["record"][side][key]=old
            if key=="unit_ref":r["record"]["before"]["visible"][1]["ref"]=old
            if key in ("before_id","after_id"):r["record"][key.split('_')[0]]["packet_id"]=old
            self.unchanged_rejection(b,r,"source_alias")

    def test_time_boundaries(self):
        b,c=setup();r=request(c);r["now_us"]+=500000;b.observe(r)
        for capture,now,reason in ((200,500201,"admission_expired"),(99,100,"capture_reversed"),(200,199,"future_capture")):
            r=request(c,2,capture);r["now_us"]=now;self.unchanged_rejection(b,r,reason)
        b.observe(request(c,2,100))  # equal acquisition time, ordered distinct event

    def test_capacity_replay_and_no_partial_write(self):
        b,c=setup()
        for i in range(1,9):b.observe(request(c,i,i*100))
        old=b.snapshot();self.unchanged_rejection(b,request(c,9,900),"notice_capacity")
        self.assertFalse(b.observe(request(c,1,100))["new_event"]);self.assertEqual(old,b.snapshot())

    def test_config_freeze_and_names_not_parameters(self):
        b,c=setup();b.configure(copy.deepcopy(c));before=b.snapshot()
        altered=copy.deepcopy(c);altered["reaction"]["base_threshold"]=9
        with self.assertRaisesRegex(ValueError,"config_conflict"):b.configure(altered)
        self.assertEqual(before,b.snapshot())
        base=b.observe(request(c))["receipt"]["evaluation"]
        c["reaction"]["profile_id"]="Episode-99-child-stranger"
        c["relation"]["relation_id"]="arbitrary-name"
        other=BoundaryDefense("run");other.configure(c);value=other.observe(request(c))["receipt"]["evaluation"]
        for k in ("load_after","threshold_reached","warning_threshold"):self.assertEqual(base[k],value[k])

    def test_output_and_input_are_detached(self):
        b,c=setup();r=request(c);v=b.observe(r);before=b.snapshot()
        c["reaction"]["base_threshold"]=9;r["record"]["notice"]["actor"]="other"
        v["receipt"]["evaluation"]["relation"]["source"]="mutated"
        s=b.snapshot();s["records"].clear();self.assertEqual(before,b.snapshot())

    def test_unknown_fields_world_truth_and_invalid_types_reject(self):
        b,c=setup()
        for part in ("notice","before","after","effect"):
            r=request(c);r["record"][part]["world_position"]={"x":2}
            self.unchanged_rejection(b,r,"invalid_fields")
        r=request(c);r["record"]["before"]["visible"][0]["distance"]=float("nan")
        self.unchanged_rejection(b,r,"invalid_distance")
        r=request(c);r["record"]["notice"]["capture_us"]=True
        self.unchanged_rejection(b,r,"notice_order")

    def test_numeric_aliases_do_not_count_as_identical_payload(self):
        b,c=setup();b.observe(request(c))
        r=request(c);r["record"]["notice"]["world_epoch"]=True
        self.unchanged_rejection(b,r,"notice_scope")
        r=request(c);r["record"]["notice"]["profile"]["revision"]=True
        self.unchanged_rejection(b,r,"notice_profile")
        r=request(c);r["record"]["effect"]["units"]=True
        self.unchanged_rejection(b,r,"effect_binding")
        r=request(c);r["record"]["before"]["order"]=1.0
        self.unchanged_rejection(b,r,"packet_binding")
        r=request(c);r["record"]["before"]["visible"][0]["distance"]=2.0
        self.unchanged_rejection(b,r,"notice_conflict")

    def test_source_order_and_after_resource_persistence(self):
        b,c=setup();r=request(c);r["record"]["before"]["order"]=3
        self.unchanged_rejection(b,r,"packet_binding")
        r=request(c);r["record"]["after"]["visible"].append(copy.deepcopy(r["record"]["before"]["visible"][1]))
        value=b.observe(r)["receipt"]
        self.assertEqual(value["status"],"unavailable");self.assertIn("pickup_not_witnessed",value["reasons"])
        self.assertIsNone(value["permit"])

    def test_concurrent_replays_have_one_admission_and_permit(self):
        b,c=setup();r=request(c)
        with ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(lambda _:b.observe(r),range(8)))
        self.assertEqual(sum(v["new_event"] for v in results),1)
        self.assertEqual(b.snapshot()["load"],4*UNIT);self.assertEqual(len(b.snapshot()["records"]),1)

    def test_warning_result_display_and_expiry_are_distinct(self):
        for status in ("displayed","action_expired"):
            b,c=setup();p=b.observe(request(c))["receipt"]["permit"]
            start=p["expires_us"]+(status=="action_expired")
            result={"permit":p,"status":status,"started_us":start,"ended_us":start+(250000 if status=="displayed" else 0),
                    "readback":"WARNING" if status=="displayed" else "","cleared":""}
            self.assertTrue(b.result(result)["new_result"]);before=b.snapshot()
            self.assertFalse(b.result(result)["new_result"]);self.assertEqual(before,b.snapshot())
            bad=copy.deepcopy(result);bad["permit"]["actor"]="foreign"
            with self.assertRaisesRegex(ValueError,"result_binding"):b.result(bad)
            bad=copy.deepcopy(result);bad["started_us"]+=1;bad["ended_us"]+=1
            with self.assertRaises(ValueError):b.result(bad)
            self.assertEqual(before,b.snapshot())

    def test_display_result_cannot_be_log_only(self):
        b,c=setup();p=b.observe(request(c))["receipt"]["permit"]
        r={"permit":p,"status":"displayed","started_us":100,"ended_us":250100,"readback":"","cleared":""}
        before=b.snapshot()
        with self.assertRaisesRegex(ValueError,"display_evidence"):b.result(r)
        self.assertEqual(before,b.snapshot())

    def test_isolated_cli_before_socket_creation(self):
        with patch("runtime.bridge.ThreadingHTTPServer") as server:
            for settings in ({"host":"0.0.0.0"},{"luanti_learning_loop":True},{"sensory_observation":True},
                             {"luanti_outcome_learning":True},{"sleep_consolidation":True},{"base_food_life":True}):
                with self.assertRaises(ValueError):run_bridge(boundary_defense=True,**settings)
            server.assert_not_called()

    def test_http_opt_in_validation_and_detached_snapshot(self):
        server=ThreadingHTTPServer(("127.0.0.1",0),BridgeHandler)
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        url=f"http://127.0.0.1:{server.server_port}"
        def post(path,data):
            with urlopen(Request(url+path,data=json.dumps(data).encode(),headers={"Content-Type":"application/json"})) as response:
                return json.load(response)
        try:
            with self.assertRaises(HTTPError) as caught:post("/v1/boundary-defense/configure",config())
            self.assertEqual(caught.exception.code,404);caught.exception.close()
            server.boundary_defense=BoundaryDefense("run")
            post("/v1/boundary-defense/configure",config())
            self.assertTrue(post("/v1/boundary-defense/observe",request(config()))["new_event"])
            before=server.boundary_defense.snapshot()
            with self.assertRaises(HTTPError) as caught:post("/v1/boundary-defense/observe",{})
            self.assertEqual(caught.exception.code,422);caught.exception.close();self.assertEqual(server.boundary_defense.snapshot(),before)
            with urlopen(url+"/v1/boundary-defense-snapshot") as response:self.assertEqual(json.load(response),before)
        finally:server.shutdown();thread.join();server.server_close()

    def test_fixed_packet_non_interference_including_nerv_and_t1(self):
        from runtime.core import decide_action
        from runtime.experience import InteractionHistory
        from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
        from test_sensory_observation import packet
        from test_neural_outcome import coordinator, success
        from runtime.luanti_outcome import LuantiOutcomeCoordinator
        def replay(enabled):
            history,canonical=InteractionHistory(),GameAIFrozenComparisonSidecar()
            neural,legacy=coordinator(),LuantiOutcomeCoordinator()
            neural.record(success());legacy.record(success())
            b,c=setup();actions=[]
            for i in range(3):
                observed=packet(f"fixed-{i}",tick=i+1)
                if enabled:b.observe(request(c,i+1,i*250000))
                action=decide_action(observed);history.register_decision(observed,action);canonical.capture(observed);actions.append(action)
            return actions,history.snapshot(),canonical.snapshot(),neural.snapshot(),legacy.snapshot()
        self.assertEqual(replay(False),replay(True))

    def test_real_luanti_matrix_replay(self):
        from integrations.luanti.tests.check_boundary_defense import check
        path=Path(__file__).parent/"fixtures/luanti_l11_replay.json"
        data=json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(len(data["runs"]),26)
        results=[check(r) for r in data["runs"]]
        main=[r for r in data["runs"] if not r["world"]["negative"]]
        self.assertEqual(len(main),24)
        self.assertEqual(sum(r["world"]["acquired"] for r in main),56)
        combinations={(r["world"]["config"]["defender"],r["world"]["config"]["relation"]["beneficiary_inclusion"],
                       r["world"]["config"]["reaction"]["base_threshold"],r["world"]["schedule"]) for r in main}
        self.assertEqual(len(combinations),24)
        self.assertEqual(sum(r["world"]["warning_count"] for r in main),10)
        self.assertTrue(any(r["world"]["loss_requested"] for r in main))
        self.assertEqual({r["negative"] for r in results if r["negative"]},{"presence","outside"})


if __name__=="__main__":unittest.main()
