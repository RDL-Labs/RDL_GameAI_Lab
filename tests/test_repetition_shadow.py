from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from integrations.luanti.tests.diagnose_movement_history import diagnose_window
from integrations.luanti.tests.repetition_shadow import RepetitionShadow, replay
from test_movement_history_diagnostic import history

TURNS = [("turn", 90), ("turn", -90)]*4
SURVEY = [("turn",-90),("move",1),("move",1),("turn",90),
          ("turn",90),("move",1),("move",1),("turn",-90)]


def window(index=0, spacing=2000000, actions=TURNS, reason="neighborhood_survey"):
    h = history(actions, reason)
    for r in h:
        for key in ("observation", "command", "result"):
            obj = r[key]
            if obj is None: continue
            for name in ("observation_id", "source_id", "operation_id"):
                if name in obj: obj[name] = str(index)+":"+obj[name]
            for name in ("capture_us", "executed_us"):
                if name in obj: obj[name] += index*spacing
        p=r["observation"]
        p["distant"]["capture_window"].update(start_us=p["capture_us"],end_us=p["capture_us"])
    return h


class RepetitionShadowTests(unittest.TestCase):
    def test_planned_survey_and_changed_purpose_do_not_suppress_response(self):
        h=window(actions=SURVEY)
        a=RepetitionShadow().observe(h)
        for r in h: r["decision"]=None
        b=RepetitionShadow().observe(h)
        self.assertEqual(a,b)
        self.assertTrue(a["shadow"]["admitted"])
        self.assertEqual(a["purpose_gate"],"not_used")

    def test_acquisition_is_kept_separately_not_a_veto(self):
        h=window(actions=SURVEY)
        h[2]["result"]["acquired"]=1
        r=RepetitionShadow().observe(h)
        self.assertTrue(r["shadow"]["admitted"])
        self.assertEqual(r["local_motion"]["acquisitions"],1)

    def test_same_evidence_different_decay_and_exact_dense_sparse_values(self):
        for spacing, expected in ((2000000,[1,1.5,2]),(6000000,[1,1,1])):
            s=RepetitionShadow();rows=[s.observe(window(i,spacing)) for i in range(3)]
            self.assertEqual([r["shadow"]["profiles"]["standard"]["residual"] for r in rows],expected)
            self.assertTrue(all(r["shadow"]["admitted"] for r in rows))
            self.assertEqual(rows[-1]["shadow"]["profiles"]["fast"]["residual"],1)
            self.assertTrue(rows[-1]["shadow"]["profiles"]["persistent"]["would_request_reassessment"])

    def test_replay_conflict_and_output_isolation_are_atomic(self):
        s=RepetitionShadow();h=window();before=deepcopy(h);a=s.observe(h)
        self.assertEqual(s.observe(h),a);a["shadow"]["profiles"].clear()
        self.assertTrue(s.observe(h)["shadow"]["profiles"])
        self.assertEqual(h,before)
        snapshot=deepcopy(s.agents);h[0]["result"]["yaw"]+=1
        with self.assertRaisesRegex(ValueError,"observation_conflict"):s.observe(h)
        self.assertEqual(s.agents,snapshot)

    def test_overlap_is_not_another_independent_contribution(self):
        s=RepetitionShadow();s.observe(window());h=window(1)
        # A coherent old operation identity in a later window still cannot vote twice.
        h[0]["command"]["operation_id"]=h[0]["result"]["operation_id"]="0:op:o0"
        r=s.observe(h)
        self.assertFalse(r["shadow"]["admitted"])
        self.assertEqual(r["shadow"]["reason"],"overlapping_operations")

    def test_unknown_decays_without_claiming_recurrence_ended(self):
        s=RepetitionShadow();s.observe(window());h=window(1)
        h[0]["result"]=None
        r=s.observe(h)
        self.assertEqual(r["shadow"]["reason"],"unknown")
        self.assertEqual(r["shadow"]["profiles"]["standard"]["residual"],.5)
        self.assertFalse(r["shadow"]["admitted"])

    def test_no_recurrence_or_short_history_does_not_contribute(self):
        for h in (window(actions=[("move",1)]*8),window(actions=TURNS[:2])):
            self.assertFalse(RepetitionShadow().observe(h)["shadow"]["admitted"])

    def test_boundaries_reject_without_partial_state(self):
        s=RepetitionShadow();s.observe(window(1));before=deepcopy(s.agents)
        with self.assertRaisesRegex(ValueError,"capture_order"):s.observe(window())
        h=window(2);h[-1]["observation"]["run_id"]="other"
        with self.assertRaisesRegex(ValueError,"shadow_binding"):s.observe(h)
        with patch("integrations.luanti.tests.repetition_shadow.MAX_OBSERVATIONS",1):
            self.assertTrue(s.observe(window(1)))
            with self.assertRaisesRegex(ValueError,"observation_budget"):s.observe(window(2))
        self.assertEqual(s.agents,before)

    def test_agent_residuals_are_independent(self):
        s=RepetitionShadow();s.observe(window());s.observe(window(1))
        h=window(2)
        for r in h:
            for key in ("observation","command","result"):
                if r[key] is not None:r[key]["agent_id"]="npc_b"
        b=s.observe(h)
        self.assertEqual(b["shadow"]["profiles"]["persistent"]["residual"],1)

    def test_cap_is_bounded_and_crossings_are_not_every_above_threshold_sample(self):
        s=RepetitionShadow();rows=[s.observe(window(i)) for i in range(8)]
        p=[r["shadow"]["profiles"]["persistent"] for r in rows]
        self.assertEqual(max(r["residual"] for r in p),4)
        self.assertTrue(all(0<=r["residual"]<=4 for r in p))
        self.assertEqual(sum(r["threshold_crossed"] for r in p),1)

    def test_nine_real_archives_exact_replay_and_v2_returns_included(self):
        root=Path(__file__).parent/"fixtures"
        report=json.loads(gzip.decompress((root/"luanti_l15a_repetition_shadow.json.gz").read_bytes()))
        actual=[]
        for name in ("luanti_l15a_steering_replay.json.gz","luanti_l15a_tie_break_replay.json.gz"):
            data=json.loads(gzip.decompress((root/name).read_bytes()))
            actual.extend(replay(r["data"]) for r in data["runs"])
        from integrations.luanti.tests.check_multi_resource import first_difference
        self.assertIsNone(first_difference(actual,report["runs"],'$history'))
        v2=[r for r in actual if r["runtime_schema"]=="l15a-terrain-resource-steering-v2"]
        rows=[w for r in v2 for ws in r["windows"].values() for w in ws]
        self.assertEqual(sum(w["shadow"]["admitted"] for w in rows),7)
        self.assertTrue(all(not p["would_request_reassessment"] for w in rows for p in w["shadow"]["profiles"].values()))
