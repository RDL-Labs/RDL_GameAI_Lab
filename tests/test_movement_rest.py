from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import unittest
from unittest.mock import patch
from runtime.movement_rest import RestResourceExploration, SCHEMA, advance_rest
from test_terrain_steering import Session as BaseSession, food_packet
from test_resource_exploration import config


class Session(BaseSession):
    def __init__(self, mode="fatigue"):
        self.multi=RestResourceExploration("r",3,assignment="steady")
        self.agent="npc_a";self.loop=self.multi.agents[self.agent]
        self.seq,self.revision,self.pose=0,0,"r:npc_a:pose:0"
        c=config();c.update(schema=SCHEMA,selection_profile="steady",rest_mode=mode)
        self.multi.configure(c)


class MovementRestTests(unittest.TestCase):
    def test_fatigue_rest_recovery_and_finite_resumption(self):
        s=Session();commands=[]
        for _ in range(14):commands.append(s.apply(food_packet(s))[0])
        ds=list(s.loop.decisions.values())
        self.assertEqual([c["kind"] for c in commands[:9]],["move"]*4+["wait"]*4+["move"])
        self.assertEqual(ds[4]["rest"]["transition"],"started")
        self.assertEqual(ds[8]["rest"]["transition"],"resumed")
        self.assertLess(ds[8]["rest"]["state"]["fatigue"],ds[4]["rest"]["state"]["fatigue"])
        self.assertEqual(len(s.loop.observations),14)

    def test_disabled_is_same_commands_and_learning_as_steering(self):
        a=Session("disabled");b=BaseSession(profile="steady")
        for i in range(16):
            pa=food_packet(a);pb=food_packet(b)
            self.assertEqual(a.apply(pa),b.apply(pb))
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.store.snapshot(),b.loop.store.snapshot())

    def test_replay_and_conflict_do_not_charge_or_rest_twice(self):
        s=Session()
        for _ in range(4):s.apply(food_packet(s))
        p=food_packet(s);response=s.multi.observe(p);before=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:
            receipts=list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(r["command"]==response["command"] for r in receipts))
        bad=deepcopy(p);bad["food"]["visible"][0]["appearance"]="changed"
        with self.assertRaises(ValueError):s.multi.observe(bad)
        self.assertEqual(s.multi.snapshot(),before)

    def test_pickup_preempts_rest_without_losing_body_history(self):
        s=Session()
        for _ in range(5):s.apply(food_packet(s))
        c,_=s.apply(s.packet())
        self.assertEqual(c["kind"],"pickup")
        self.assertEqual(next(reversed(s.loop.decisions.values()))["rest"]["transition"],"interrupted")

    def test_missing_result_is_not_recovery_or_body_authority(self):
        s=Session();p=food_packet(s);s.multi.observe(p);s.seq+=1
        c=s.multi.observe(food_packet(s))["command"]
        d=next(reversed(s.loop.decisions.values()))
        self.assertEqual(c["reason"],"body_correspondence_unavailable")
        self.assertEqual(d["rest"]["accounting"]["recovery"],0)

    def test_pure_accounting_actual_effects_only_and_no_double_charge(self):
        rec=dict(sources=[],operations=[],repetition_eligible=False)
        results={"o":dict(forward=1,right=0,up=0,yaw=90,status="moved")}
        s,a=advance_rest(None,0,0,results,None,None,False,rec)
        self.assertEqual(s["fatigue"],1.25)
        s,a=advance_rest(s,2000000,0,results,None,None,False,rec)
        self.assertEqual(a["effort"],0);self.assertEqual(s["fatigue"],1.25)

    def test_wait_recovery_is_bounded_and_separate_from_repetition(self):
        rec=dict(sources=list(range(9)),operations=list(range(8)),repetition_eligible=True)
        s,a=advance_rest(None,0,0,{},None,None,False,rec);s["fatigue"]=4
        s,a=advance_rest(s,10000000,0,{},dict(status="waited",executed_us=0),0,True,rec)
        self.assertEqual(s["fatigue"],3.5);self.assertAlmostEqual(s["residual"],.9)
        self.assertFalse(a["contribution"])

    def test_failed_admission_keeps_decision_fatigue_atomic(self):
        s=Session();s.apply(food_packet(s));p=food_packet(s)
        before=s.multi.snapshot();p["distant"]["payload"]["world_id"]="forbidden"
        with self.assertRaises(ValueError):s.multi.observe(p)
        self.assertEqual(s.multi.snapshot(),before)

    def test_mode_configuration_conflict_is_rejected(self):
        s=Session();c=config();c.update(schema=SCHEMA,selection_profile="steady",rest_mode="combined")
        before=s.multi.snapshot()
        with self.assertRaisesRegex(ValueError,"rest_configuration_conflict"):s.multi.configure(c)
        self.assertEqual(s.multi.snapshot(),before)

    def test_repetition_request_consumption_with_synthetic_detector(self):
        # Arbitration-only fixture; not evidence that this straight trajectory repeats.
        s=Session("repetition")
        def detector(records, **kwargs):
            seq=records[-1]["observation"]["sample_seq"]
            return dict(sources=list(range(9)),operations=[f"{seq}:{i}" for i in range(8)],
                        repetition_eligible=seq in (8,16,24))
        with patch("runtime.movement_rest.diagnose_window",detector):
            for _ in range(29):s.apply(food_packet(s))
        ds=list(s.loop.decisions.values())
        starts=[d for d in ds if d["rest"]["transition"]=="started"]
        self.assertEqual(len(starts),1)
        self.assertEqual(starts[0]["rest"]["state"]["active"]["reasons"],["repetition"])
        self.assertLess(starts[0]["rest"]["state"]["residual"],1)
        self.assertEqual(ds[28]["rest"]["transition"],"resumed")

    def test_repeated_rest_starts_respect_each_decision_budget(self):
        s=Session()
        for _ in range(5):s.apply(food_packet(s))
        # Existing source times advance normally: at most four waits per rest.
        for _ in range(30):s.apply(food_packet(s))
        counts={}
        for d in s.loop.decisions.values():
            a=d["rest"]["state"]["active"]
            if a:counts[a["source"]]=counts.get(a["source"],0)+1
        self.assertTrue(counts)
        self.assertTrue(all(n<=4 for n in counts.values()))

    def test_archived_live_runs_when_available(self):
        path=Path(__file__).parent/"fixtures/luanti_l15a_movement_rest.json.gz"
        if not path.exists():self.skipTest("World run not yet generated")
        from integrations.luanti.tests.check_movement_rest import check
        data=json.loads(gzip.decompress(path.read_bytes()))
        self.assertEqual(len(data["runs"]),5)
        for r in data["runs"]:self.assertEqual(check(r["data"]),r["summary"])
        from runtime.terrain_steering import SteeredResourceExploration, SCHEMA as BASE
        disabled=data["runs"][0]["data"]
        state=disabled["runtime"]["exploration"]
        loop=SteeredResourceExploration(state["run_id"],state["periods"],state["seed"],state["assignment"])
        for delivery in disabled["world"]["deliveries"]:
            value=deepcopy(delivery["request"])
            if delivery["kind"]=="configure":
                value.pop("rest_mode");value["schema"]=BASE
            response=getattr(loop,delivery["kind"])(value)
            if delivery["kind"]=="observe":
                self.assertEqual(response,json.loads(delivery["response_wire"]))
        old=loop.snapshot()
        for aid in state["agents"]:
            for key in ("learning","active_model","sensory","commands","observations","results","inventory"):
                self.assertEqual(old["agents"][aid][key],state["agents"][aid][key])
