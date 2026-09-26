import copy
import json
from functools import lru_cache
from pathlib import Path
import unittest

from runtime.observation_v1 import evaluate
from runtime.continuous_visual_probe import evaluate as old_evaluate
from runtime.visual_reacquisition import ProbeInputError
from runtime.sensory_observation import SensoryObservationStore
from runtime.core import ObservationError, decide_action
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from integrations.luanti.tests.check_observation_v1 import check
from test_sensory_observation import packet

FIXTURE=Path(__file__).parent / "fixtures/obs9_luanti_replay.json"


@lru_cache
def recorded():
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def capture(scenario="normal"):
    return copy.deepcopy(next(c for c in recorded()["captures"] if c["evidence"]["scenario"]==scenario))


def data(scenario="normal"):
    c=capture(scenario)
    return c["snapshot"],c["evidence"]["request"],c["evidence"]["evidence"]


def target(s,e):
    return next(f for f in s["frames"] if f["frame_id"]==e["new_frame_id"])


def readmit(c):
    s=c["snapshot"]
    store=SensoryObservationStore(run_id=s["run_id"],assignments={
        "npc_a":("fixture-life-sensory",1),"npc_b":("fixture-life-sensory-compact",1)})
    batches=[]
    for aid in ("npc_a","npc_b"):
        fs=[f for f in c["evidence"]["acquired_frames"] if f["agent_id"]==aid]
        for offset in range(0,len(fs),4):
            observed=packet(f"{aid}-{offset}",aid,24)
            ext={"schema_version":"rdl-sensory-extension-v1","run_id":s["run_id"],"world_epoch":1,
                 "agent_id":aid,"delivery_observation_id":observed["observation_id"],
                 "delivery_world_tick":24,"delivery_time_us":6000000,"frames":fs[offset:offset+4]}
            receipt=store.admit(observed,ext)
            assert receipt["accepted"] and receipt["new_frames"]==len(ext["frames"])
            batches.append((observed,ext))
    return store,batches


class ObservationV1Tests(unittest.TestCase):
    def test_eight_real_integrated_runs(self):
        self.assertEqual(len(recorded()["captures"]),8)
        for c in recorded()["captures"]:
            with self.subTest(c["evidence"]["scenario"]): check(c["snapshot"],c["evidence"])

    def test_roles_swapped_with_independent_profiles(self):
        for scenario,aid in [("normal","npc_a"),("swap","npc_b")]:
            s,r,e=data(scenario)
            self.assertEqual(r["agent_id"],aid)
            self.assertEqual(evaluate(s,r,e)["status"],"reobserved")

    def test_old_rule_does_not_accept_life_profiles(self):
        for scenario in ("normal","swap"):
            s,r,e=data(scenario);r["rule_version"]="obs8b-v1"
            self.assertIn("unsupported_conditions",old_evaluate(s,r,e)["comparison_reasons"])
            with self.assertRaises(ProbeInputError): evaluate(s,r,e)

    def test_equivalent_visual_records_under_explicit_rule(self):
        s,r,e=data();v1=evaluate(s,r,e)
        for f in s["frames"]: f["profile_id"]="fixture-distant-enabled"
        r["rule_version"]="obs8b-v1";old=old_evaluate(s,r,e)
        for key in ("status","matches","inspection_region","comparison_reasons","acquisition_reasons"):
            self.assertEqual(v1[key],old[key])

    def test_two_allowed_profiles_do_not_allow_profile_change(self):
        s,r,e=data();target(s,e)["profile_id"]="fixture-life-sensory-compact"
        out=evaluate(s,r,e)
        self.assertEqual(out["status"],"not_comparable")
        self.assertIn("unsupported_conditions",out["comparison_reasons"])
        self.assertIsNone(out["matches"])

    def test_unknown_profile_or_revision_is_not_comparable(self):
        for key,value in [("profile_id","unknown"),("profile_revision",2)]:
            s,r,e=data();target(s,e)[key]=value
            self.assertIn("unsupported_conditions",evaluate(s,r,e)["comparison_reasons"])

    def test_actual_capture_time_is_not_rounded(self):
        s,r,e=data();f=target(s,e)
        self.assertNotEqual(f["capture_window"]["start_us"],f["sampled_world_tick"]*250000)
        self.assertEqual(evaluate(s,r,e)["status"],"reobserved")
        f["capture_window"].update(start_us=1250000,end_us=1250000);e["pose"]["target_us"]=1250000
        self.assertIn("invalid_acquisition_slot",evaluate(s,r,e)["comparison_reasons"])

    def test_complete_observation_can_be_not_comparable(self):
        s,r,e=data();e["pose"]["valid"]=False
        out=evaluate(s,r,e)
        self.assertEqual(out["status"],"not_comparable")
        self.assertEqual(out["acquisition_status"],"complete")
        self.assertIsNone(out["matches"])

    def test_partial_and_pose_failure_both_survive(self):
        s,r,e=data("partial");e["pose"]["valid"]=False
        out=evaluate(s,r,e)
        self.assertEqual(out["status"],"acquisition_incomplete")
        self.assertIn("incomplete_frame",out["acquisition_reasons"])
        self.assertIn("pose_mapping_unavailable",out["comparison_reasons"])
        self.assertIsNone(out["matches"])

    def test_absence_and_aborted_are_distinct(self):
        s,r,e=data("removed");out=evaluate(s,r,e)
        self.assertEqual(out["status"],"not_reobserved");self.assertEqual(out["matches"],[])
        s,r,e=data("preempt");out=evaluate(s,r,e)
        self.assertEqual(out["status"],"aborted");self.assertIsNone(out["matches"])
        self.assertEqual(out["acquisition_status"],"not_acquired")

    def test_all_matching_records_retained_without_identity(self):
        s,r,e=data();f=target(s,e);extra=copy.deepcopy(f["payload"]["features"][0]);extra["feature_id"]="second"
        f["payload"]["features"].append(extra)
        out=evaluate(s,r,e)
        self.assertEqual(len(out["matches"]),2)
        self.assertIn("not-object-identity",out["authority"])

    def test_cross_agent_run_and_unknown_frame_rejected(self):
        for key,value in [("agent_id","npc_b"),("run_id","old"),("source_frame_id","unknown")]:
            s,r,e=data();r[key]=value
            with self.assertRaises(ProbeInputError): evaluate(s,r,e)
        s,r,e=data();e["new_frame_id"]="unadmitted"
        with self.assertRaises(ProbeInputError): evaluate(s,r,e)

    def test_full_record_readmission_and_duplicate_replay(self):
        c=capture("faults");store,batches=readmit(c)
        before=store.snapshot()
        for observed,ext in batches:
            self.assertEqual(store.admit(observed,ext)["new_frames"],0)
        self.assertEqual(store.snapshot(),before)
        self.assertEqual(before["count"],108)
        self.assertEqual(evaluate(before,c["evidence"]["request"],c["evidence"]["evidence"])["status"],"reobserved")

    def test_world_truth_rejected_by_admission_schema(self):
        c=capture();store,batches=readmit(c)
        for channel,key in [("vision_distant","position"),("audition","source_id")]:
            observed,ext=copy.deepcopy(next((p,x) for p,x in batches if any(f["channel"]==channel for f in x["frames"])))
            frame=next(f for f in ext["frames"] if f["channel"]==channel)
            frame["payload"][key]=[1,2,3]
            before=store.snapshot()
            with self.assertRaises(ObservationError): store.admit(observed,ext)
            self.assertEqual(store.snapshot(),before)

    def test_input_output_independent(self):
        s,r,e=data();before=copy.deepcopy((s,r,e));out=evaluate(s,r,e)
        self.assertEqual((s,r,e),before)
        out["new_frame"]["payload"].clear();out["evidence"].clear()
        self.assertEqual((s,r,e),before)

    def test_fixed_packet_evaluation_non_interference(self):
        c=capture();store,_=readmit(c);r=c["evidence"]["request"];e=c["evidence"]["evidence"]
        def replay(enabled):
            history,canonical=InteractionHistory(),GameAIFrozenComparisonSidecar();actions=[]
            for i in range(3):
                observed=packet(f"fixed-{i}",tick=i+1)
                if enabled: evaluate(store.snapshot(),r,e)
                action=decide_action(observed);history.register_decision(observed,action);canonical.capture(observed);actions.append(action)
            return actions,history.snapshot(),canonical.snapshot(),store.snapshot()
        self.assertEqual(replay(False),replay(True))

    def test_delivery_body_does_not_rewrite_acquisition(self):
        s,r,e=data("delayed");e["final_translation"]=10000
        self.assertEqual(evaluate(s,r,e)["status"],"reobserved")
        e["pose"]["translation"]=1
        self.assertIn("body_changed",evaluate(s,r,e)["comparison_reasons"])


if __name__ == "__main__": unittest.main()
