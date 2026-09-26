import copy
import json
from pathlib import Path
import unittest
from runtime.visual_reacquisition import evaluate, circular_parts, overlap, ProbeInputError
from runtime.sensory_observation import SensoryObservationStore
from integrations.luanti.tests.check_visual_probe import check
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_sensory_observation import packet


def recorded():
    return json.loads((Path(__file__).parent / "fixtures/obs8_luanti_replay.json").read_text(encoding="utf-8"))


def sample():
    data = recorded()
    r = data["body_evidence"]["records"][0]
    return data["snapshot"], r["request"], r["evidence"]


def target(snapshot, evidence):
    return next(f for f in snapshot["frames"] if f["frame_id"] == evidence["new_frame_id"])


class VisualReacquisitionTests(unittest.TestCase):
    def test_real_luanti_cases_and_lua_boundaries(self):
        data = recorded()
        self.assertEqual(len(check(data["snapshot"], data["body_evidence"])), 15)
        self.assertGreaterEqual(data["body_evidence"]["controller_checks"], 40)

    def test_real_store_reacceptance_and_duplicate_delivery(self):
        snapshot, request, evidence = sample()
        store = SensoryObservationStore(assignments={"npc_a": ("fixture-distant-enabled", 1)}, run_id=snapshot["run_id"])
        frames = [next(f for f in snapshot["frames"] if f["frame_id"] == request["source_frame_id"]), target(snapshot, evidence)]
        ext = {"schema_version": "rdl-sensory-extension-v1", "run_id": snapshot["run_id"], "world_epoch": 1,
               "agent_id": "npc_a", "delivery_observation_id": "admit", "delivery_world_tick": 8,
               "delivery_time_us": 2000000, "frames": [{k:v for k,v in f.items() if k not in ("run_id", "world_epoch")} for f in frames]}
        self.assertEqual(store.admit(packet("admit", tick=8), ext)["new_frames"], 2)
        before = evaluate(store.snapshot(), request, evidence)
        self.assertEqual(store.admit(packet("admit", tick=8), ext)["new_frames"], 0)
        self.assertEqual(before, evaluate(store.snapshot(), request, evidence))
        self.assertEqual(before["status"], "reobserved")

    def test_inputs_and_output_are_detached(self):
        s,r,e=sample(); before=copy.deepcopy((s,r,e)); out=evaluate(s,r,e)
        out["source_frame"]["payload"]["features"].clear(); out["evidence"]["pose"].clear()
        self.assertEqual((s,r,e),before)

    def test_circular_parts_and_positive_overlap(self):
        self.assertEqual(circular_parts([175,185]), [(175,180),(-180,-175)])
        self.assertTrue(overlap(circular_parts([175,185]), circular_parts([-179,-174])))
        self.assertFalse(overlap([(0,5)],[(5,10)]))
        for angle in range(-180,180,5):
            self.assertTrue(overlap(circular_parts([angle,angle+5],360),circular_parts([angle,angle+5])))

    def test_missing_pose_never_uses_command(self):
        for key, value in [("valid",False),("start_to_target_deg",None),("source_ref","wrong"),("target_ref","wrong"),("clock_id","other"),("issuer","unknown")]:
            s,r,e=sample();e["pose"][key]=value
            self.assertEqual(evaluate(s,r,e)["status"],"not_comparable",key)

    def test_actual_rotation_mismatch_is_not_reobserved(self):
        s,r,e=sample();e["pose"]["start_to_target_deg"] += 2
        self.assertIn("rotation_unconfirmed",evaluate(s,r,e)["comparison_reasons"])

    def test_incomplete_and_incomparable_preserved_separately(self):
        for field,value in [("coverage","PARTIAL"),("status","UNAVAILABLE"),("output_limited",True)]:
            s,r,e=sample();target(s,e)[field]=value;e["pose"]["valid"]=False
            result=evaluate(s,r,e)
            self.assertEqual(result["status"],"acquisition_incomplete")
            self.assertIn("pose_mapping_unavailable",result["comparison_reasons"])
            self.assertIsNone(result["matches"])

    def test_complete_empty_is_only_record_absence(self):
        s,r,e=sample();target(s,e)["payload"]["features"]=[]
        self.assertEqual(evaluate(s,r,e)["status"],"not_reobserved")
        target(s,e)["coverage"]="PARTIAL"
        self.assertEqual(evaluate(s,r,e)["status"],"acquisition_incomplete")

    def test_unknown_feature_prevents_negative_verdict(self):
        for key in ("color_band","azimuth_interval_deg","elevation_interval_deg"):
            s,r,e=sample();target(s,e)["payload"]["features"][0][key]="unknown"
            self.assertEqual(evaluate(s,r,e)["status"],"not_comparable")

    def test_fov_and_profile_conditions(self):
        s,r,e=sample();e["pose"]["source_to_start_deg"]=80
        self.assertIn("region_outside_fov",evaluate(s,r,e)["comparison_reasons"])
        for key,value in [("profile_id","fixture-life-sensory"),("profile_revision",2),("sensor_id","other"),("clock_id","other")]:
            s,r,e=sample();target(s,e)[key]=value
            self.assertEqual(evaluate(s,r,e)["status"],"not_comparable")

    def test_age_and_duration_boundaries(self):
        s,r,e=sample();f=target(s,e)
        f["capture_window"].update(start_us=2000000,end_us=2000000);f["sampled_world_tick"]=8
        e.update(started_us=500000,rotation_completed_us=1000000,sample_tick=8)
        e["pose"].update(start_us=500000,target_us=2000000,expires_us=2000000)
        self.assertEqual(evaluate(s,r,e)["status"],"reobserved")
        e["started_us"]-=1;e["pose"]["start_us"]-=1
        self.assertIn("time_or_expiry",evaluate(s,r,e)["comparison_reasons"])
        e["started_us"]+=1;e["pose"]["start_us"]+=1;e["pose"]["expires_us"]-=1
        self.assertIn("time_or_expiry",evaluate(s,r,e)["comparison_reasons"])

    def test_same_tick_and_extra_sample_rejected(self):
        for key,value in [("samples",2),("rotations",2),("sample_tick",5)]:
            s,r,e=sample();e[key]=value
            self.assertEqual(evaluate(s,r,e)["status"],"not_comparable")
        s,r,e=sample();e["rotation_completed_us"]=target(s,e)["capture_window"]["start_us"]
        self.assertIn("time_or_expiry",evaluate(s,r,e)["comparison_reasons"])

    def test_pose_error_and_movement_limits(self):
        for key,value in [("error_deg",0.02),("translation",0.001),("tilt_deg",1),("error_deg",-1),("start_to_target_deg",float('nan'))]:
            s,r,e=sample();e["pose"][key]=value
            self.assertEqual(evaluate(s,r,e)["status"],"not_comparable")

    def test_input_errors_atomic_and_no_unadmitted_target(self):
        for key,value in [("source_frame_id","missing"),("feature_id","missing"),("agent_id","npc_b"),("run_id","old"),("color_band","dark_gray"),("purpose","other")]:
            s,r,e=sample();r[key]=value
            with self.assertRaises(ProbeInputError): evaluate(s,r,e)
        s,r,e=sample();e["new_frame_id"]="unadmitted"
        with self.assertRaises(ProbeInputError): evaluate(s,r,e)

    def test_not_acquired_is_distinct_from_empty(self):
        s,r,e=sample();e["new_frame_id"]=None
        self.assertEqual(evaluate(s,r,e)["status"],"acquisition_incomplete")

    def test_snapshot_order_does_not_change_evaluation(self):
        s,r,e=sample();before=evaluate(s,r,e);s["frames"].reverse()
        self.assertEqual(evaluate(s,r,e),before)

    def test_color_mismatch_and_nonoverlapping_intervals(self):
        for field,value in [("color_band","dark_gray"),("azimuth_interval_deg",[10,15]),("elevation_interval_deg",[5,10])]:
            s,r,e=sample();target(s,e)["payload"]["features"][0][field]=value
            self.assertEqual(evaluate(s,r,e)["status"],"not_reobserved")

    def test_fixed_packet_non_interference(self):
        s,r,e=sample()
        def replay(enabled):
            history,canonical=InteractionHistory(),GameAIFrozenComparisonSidecar();actions=[]
            for i in range(3):
                observed=packet(f"fixed-{i}",tick=i+1)
                if enabled: evaluate(s,r,e)
                action=decide_action(observed);history.register_decision(observed,action);canonical.capture(observed);actions.append(action)
            return actions,history.snapshot(),canonical.snapshot(),s
        self.assertEqual(replay(False),replay(True))


if __name__ == "__main__": unittest.main()
