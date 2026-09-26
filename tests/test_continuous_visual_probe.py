import copy
import json
from pathlib import Path
import unittest
from runtime.continuous_visual_probe import evaluate
from runtime.visual_reacquisition import evaluate as evaluate_original, ProbeInputError
from runtime.sensory_observation import SensoryObservationStore
from integrations.luanti.tests.check_continuous_probe import check
from test_sensory_observation import packet

FIXTURE = Path(__file__).parent / "fixtures/obs8b_luanti_replay.json"


def captures():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))["captures"]


def data():
    c = next(c for c in captures() if c["evidence"]["scenario"] == "delayed")
    return c["snapshot"], c["evidence"]["request"], c["evidence"]["evidence"]


def target(s,e):
    return next(f for f in s["frames"] if f["frame_id"]==e["new_frame_id"])


class ContinuousVisualProbeTests(unittest.TestCase):
    def test_six_real_luanti_cases(self):
        cs=captures();self.assertEqual(len(cs),6)
        for c in cs:
            with self.subTest(c["evidence"]["scenario"]): check(c["snapshot"],c["evidence"])

    def test_actual_time_preserved_and_old_rule_stays_strict(self):
        s,r,e=data();before=copy.deepcopy((s,r,e))
        result=evaluate(s,r,e)
        self.assertEqual(result["status"],"reobserved")
        self.assertNotEqual(target(s,e)["capture_window"]["start_us"],e["sample_tick"]*250000)
        self.assertEqual(before,(s,r,e))
        r["rule_version"]="obs8-v1"
        self.assertIn("invalid_acquisition_slot",evaluate_original(s,r,e)["comparison_reasons"])
        with self.assertRaises(ProbeInputError): evaluate(s,r,e)

    def test_slot_end_is_exclusive(self):
        s,r,e=data();f=target(s,e);time=(e["sample_tick"]+1)*250000
        f["capture_window"].update(start_us=time,end_us=time);e["pose"]["target_us"]=time
        self.assertIn("invalid_acquisition_slot",evaluate(s,r,e)["comparison_reasons"])
        f["capture_window"].update(start_us=time-1,end_us=time-1);e["pose"]["target_us"]=time-1
        self.assertEqual(evaluate(s,r,e)["status"],"reobserved")

    def test_next_slot_cannot_be_replaced_by_later_slot(self):
        s,r,e=data();f=target(s,e);time=2000001
        f["capture_window"].update(start_us=time,end_us=time);f["sampled_world_tick"]=8
        e["sample_tick"]=8;e["pose"]["target_us"]=time
        self.assertIn("invalid_acquisition_slot",evaluate(s,r,e)["comparison_reasons"])

    def test_same_time_as_rotation_is_not_new_acquisition(self):
        s,r,e=data();e["rotation_completed_us"]=target(s,e)["capture_window"]["start_us"]
        self.assertIn("time_or_expiry",evaluate(s,r,e)["comparison_reasons"])

    def test_historical_evaluation_does_not_use_final_body(self):
        s,r,e=data();e["final_translation"]=1000
        self.assertEqual(evaluate(s,r,e)["status"],"reobserved")
        e["pose"]["translation"]=1
        self.assertIn("body_changed",evaluate(s,r,e)["comparison_reasons"])

    def test_real_admission_and_duplicate_frames(self):
        s,r,e=data();store=SensoryObservationStore(assignments={"npc_a":("fixture-distant-enabled",1)},run_id=s["run_id"])
        fs=[next(f for f in s["frames"] if f["frame_id"]==r["source_frame_id"]),target(s,e)]
        ext={"schema_version":"rdl-sensory-extension-v1","run_id":s["run_id"],"world_epoch":1,"agent_id":"npc_a",
             "delivery_observation_id":"late","delivery_world_tick":23,"delivery_time_us":5900000,
             "frames":[{k:v for k,v in f.items() if k not in ("run_id","world_epoch")} for f in fs]}
        self.assertEqual(store.admit(packet("late",tick=23),ext)["new_frames"],2)
        self.assertEqual(store.admit(packet("late",tick=23),ext)["new_frames"],0)
        self.assertEqual(evaluate(store.snapshot(),r,e)["status"],"reobserved")

    def test_output_does_not_alias_evidence_or_frames(self):
        s,r,e=data();before=copy.deepcopy((s,r,e));out=evaluate(s,r,e)
        out["evidence"]["pose"].clear();out["new_frame"]["payload"].clear()
        self.assertEqual((s,r,e),before)

    def test_partial_and_missing_pose_stay_distinct(self):
        s,r,e=data();target(s,e)["coverage"]="PARTIAL";e["pose"]["valid"]=False
        out=evaluate(s,r,e)
        self.assertEqual(out["status"],"acquisition_incomplete")
        self.assertIn("pose_mapping_unavailable",out["comparison_reasons"])
        self.assertIsNone(out["matches"])

    def test_cross_context_and_unadmitted_frame_rejected(self):
        for field,value in [("run_id","old"),("agent_id","npc_b"),("source_frame_id","unknown")]:
            s,r,e=data();r[field]=value
            with self.assertRaises(ProbeInputError): evaluate(s,r,e)
        s,r,e=data();e["new_frame_id"]="unadmitted"
        with self.assertRaises(ProbeInputError): evaluate(s,r,e)

    def test_life_priority_aborted_has_no_reacquisition(self):
        for c in captures():
            if c["evidence"]["scenario"] in ("preempt","same_slot","jump"):
                e=c["evidence"]["evidence"]
                self.assertEqual(e["samples"],0)
                self.assertIsNone(evaluate(c["snapshot"],c["evidence"]["request"],e)["evaluation"])

    def test_arbitration_provenance_no_world_target_data(self):
        forbidden={"position","object_id","node_name","distance","source_id"}
        def walk(x):
            if isinstance(x,dict):
                self.assertFalse(forbidden & x.keys())
                for v in x.values(): walk(v)
            elif isinstance(x,list):
                for v in x: walk(v)
        for c in captures():
            walk(c["evidence"]["request"]);walk(c["evidence"]["evidence"]);walk(c["snapshot"]["frames"])


if __name__ == "__main__": unittest.main()
