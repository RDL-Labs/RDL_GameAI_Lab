from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest

from integrations.luanti.tests.diagnose_movement_history import diagnose_window, analyze
from test_exploration import packet, result
from test_resource_exploration import material
from test_terrain_resource_exploration import surface


def history(actions,reason="observed_material_terrain_turn_minimum"):
    records=[];revision=0;pose="pose0"
    for i in range(len(actions)+1):
        p=packet(i);p.update(pose_ref=pose,body_revision=revision)
        p["food"]["visible"]=[material(distance=5)];p["movement_surface"]=surface(p)
        c=r=None
        if i<len(actions):
            kind,amount=actions[i]
            c={k:p[k] for k in ("run_id","world_epoch","agent_id","pose_ref","body_revision","capture_us")}
            c.update(source_id=p["observation_id"],operation_id="op:"+p["observation_id"],
                kind=kind,amount=amount,reason=reason)
            r=result(c,dict(move="moved",turn="turned",wait="waited",pickup="picked_up")[kind]);r["up"]=0
            revision=r["after_revision"];pose="pose"+str(revision);r["after_pose_ref"]=pose
        records.append(dict(observation=p,command=c,result=r,decision=dict(approach=dict(ref="m"))))
    return records


class MovementHistoryTests(unittest.TestCase):
    def test_no_motion_symmetric_reversal_is_only_a_scoped_candidate(self):
        r=diagnose_window(history([("turn",90),("turn",-90)]))
        self.assertEqual(r["status"],"stationary_reversal_candidate")
        self.assertTrue(r["repetition_eligible"])

    def test_out_and_back_is_not_stagnation_when_survey_is_the_purpose(self):
        actions=[("turn",-90),("move",1),("move",1),("turn",90),("turn",90),("move",1),("move",1),("turn",-90)]
        survey=diagnose_window(history(actions,"neighborhood_survey"))
        approach=diagnose_window(history(actions))
        self.assertEqual(survey["local_motion"],approach["local_motion"])
        self.assertEqual(survey["status"],"movement_return_candidate")
        self.assertEqual(survey["purpose_gate"],"planned_survey")
        self.assertFalse(survey["repetition_eligible"])
        self.assertTrue(approach["repetition_eligible"])

    def test_turn_then_forward_uses_measured_body_relative_displacement(self):
        r=diagnose_window(history([("turn",90),("move",1)]))
        self.assertAlmostEqual(r["local_motion"]["right"],1)
        self.assertAlmostEqual(r["local_motion"]["forward"],0)
        self.assertFalse(r["repetition_eligible"])

    def test_current_view_similarity_cannot_replace_measured_motion(self):
        r=diagnose_window(history([("move",1)]*8))
        self.assertTrue(r["same_coarse_view"])
        self.assertEqual(r["local_motion"]["net_distance"],8)
        self.assertFalse(r["repetition_eligible"])

    def test_pickup_is_progress_even_at_the_same_position(self):
        r=diagnose_window(history([("turn",90),("pickup",0),("turn",-90)]))
        self.assertEqual(r["status"],"acquisition_progress")
        self.assertFalse(r["repetition_eligible"])

    def test_incomplete_missing_late_and_wrong_pose_are_unknown(self):
        for cause in ("incomplete","unavailable_ray","missing","late","pose"):
            h=history([("turn",90),("turn",-90)])
            if cause=="incomplete":h[-1]["observation"]["food"]["coverage"]="partial"
            elif cause=="unavailable_ray":h[-1]["observation"]["movement_surface"]["ground"]["samples"][0].update(status="unavailable",height_delta=None)
            elif cause=="missing":h[0]["result"]=None
            elif cause=="late":h[0]["result"]["executed_us"]=h[1]["observation"]["capture_us"]
            else:h[0]["result"]["after_pose_ref"]="wrong"
            r=diagnose_window(h);self.assertEqual(r["status"],"unknown")
            self.assertIsNone(r["local_motion"]);self.assertFalse(r["repetition_eligible"])

    def test_goal_change_and_visible_progress_block_repetition_admission(self):
        for kind in ("goal","range"):
            h=history([("turn",90),("turn",-90)])
            if kind=="goal":h[-1]["decision"]["approach"]["ref"]="other"
            else:h[-1]["observation"]["food"]["visible"][0]["distance"]=4.6
            r=diagnose_window(h)
            self.assertFalse(r["repetition_eligible"])
            self.assertIn(r["purpose_gate"],("purpose_not_stable_food_approach","observed_range_progress"))

    def test_budget_duplicates_and_cross_agent_are_rejected(self):
        h=history([("wait",0)]*8)
        with self.assertRaisesRegex(ValueError,"history_budget"):diagnose_window(h+[h[-1]])
        h=history([("wait",0)]*2);h[-1]["observation"]["agent_id"]="npc_b"
        with self.assertRaisesRegex(ValueError,"history_binding"):diagnose_window(h)
        h=history([("wait",0)]*2);h[-1]=deepcopy(h[0])
        with self.assertRaisesRegex(ValueError,"duplicate_observation"):diagnose_window(h)

    def test_analysis_does_not_mutate_records(self):
        h=history([("turn",90),("turn",-90)]);before=deepcopy(h)
        r=diagnose_window(h);r["sources"].clear()
        self.assertEqual(h,before)

    def test_actual_nine_run_diagnostic_replays_and_preserves_planned_returns(self):
        root=Path(__file__).parent/"fixtures"
        report=json.loads(gzip.decompress((root/"luanti_l15a_history_diagnostic.json.gz").read_bytes()))
        results=[]
        for name in ("luanti_l15a_steering_replay.json.gz","luanti_l15a_tie_break_replay.json.gz"):
            matrix=json.loads(gzip.decompress((root/name).read_bytes()))
            results.extend(analyze(r["data"]) for r in matrix["runs"])
        from integrations.luanti.tests.check_multi_resource import first_difference
        self.assertIsNone(first_difference(results,report["runs"],'$history'))
        steering=[r for r in results if r["runtime_schema"]=="l15a-terrain-resource-steering-v2"]
        returns=[w for r in steering for rows in r["windows"].values() for w in rows if w["status"]=="movement_return_candidate"]
        self.assertEqual(len(returns),7)
        self.assertTrue(all(w["purpose_gate"]=="planned_survey" and not w["repetition_eligible"] for w in returns))
        self.assertTrue(all(sum(r["repetition_eligible_counts"].values())==0 for r in steering))
