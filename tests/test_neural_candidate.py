import copy
import unittest
from unittest.mock import patch

from runtime.neural_candidate import build_neural_candidate as build, NeuralCandidateError, RULE
from runtime.neural_outcome import NeuralOutcomeCoordinator
from runtime.functions.local_bias_t1_projection import project_local_bias_candidate, LocalBiasT1ProjectionError
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_neural_outcome import param, success, synthetic_dimensions
from test_sensory_observation import packet


def fixture(count=3,s=3,t=0,edits=None):
    c=NeuralOutcomeCoordinator("r",[param(s=s,t=t)])
    for i in range(count):
        payload=success(i)
        dims=None
        if edits: dims=edits(i,payload)
        if dims is not None:
            with patch("runtime.outcome_bias._dimensions",return_value=dims): c.record(payload)
        else: c.record(payload)
    return c


def request(c,ids=None):
    m=c.sleep_materials("npc_a")
    return {"run_id":"r","agent_id":"npc_a","parameter_id":"param-npc_a","parameter_revision":1,
            "rule_version":RULE,"source_experience_ids":ids if ids is not None else [p["source_experience_id"] for p in m["projections"]],
            "sleep_cycle":"cycle","formation_tick":20}


def evaluate(c): return build(c.sleep_materials("npc_a"),request(c))

def names(out): return {g["signature"]["relation"] for g in out["candidate"]["common_relations"]}


class NeuralCandidateTests(unittest.TestCase):
    def test_four_corners_and_equal_high_reward(self):
        expected={(1,1):{"acquisition","return"},(1,3):{"acquisition","return"},
                  (3,1):{"acquisition","return","injury","reward_value"},(3,3):{"acquisition","return","injury"}}
        for (s,t),relations in expected.items():
            out=evaluate(fixture(s=s,t=t));self.assertEqual(names(out),relations)
            self.assertEqual(out["candidate"]["support_count"],3)
            def high(i,p): p["outcome_facts"].update(reward_value="HIGH",injury_level="none")
            self.assertEqual(names(evaluate(fixture(s=s,t=t,edits=high))),{"acquisition","return","reward_value"})

    def test_six_experiences_fifteen_pairs_sixty_comparisons(self):
        out=evaluate(fixture(6))
        self.assertEqual(len(out["pair_results"]),15)
        self.assertEqual(sum(len(p["relations"]) for p in out["pair_results"]),60)
        for g in out["candidate"]["common_relations"]:
            self.assertEqual(g["support_count"],6)
            self.assertEqual(len(set(g["source_experience_ids"])),6)

    def test_replay_and_sleep_calls_do_not_increase_support(self):
        c=fixture();out=evaluate(c);before=c.snapshot()
        c.record(success(0));self.assertEqual(out,evaluate(c))
        r=request(c);r["sleep_cycle"]="another";r["formation_tick"]=40
        second=build(c.sleep_materials("npc_a"),r)
        self.assertNotEqual(out["candidate"]["candidate_id"],second["candidate"]["candidate_id"])
        self.assertEqual(second["candidate"]["support_count"],3)
        self.assertEqual(c.snapshot(),before)

    def test_insufficient_experience_counts(self):
        for n in (0,1,2):
            out=evaluate(fixture(n));self.assertEqual(out["status"],"insufficient_experiences")
            self.assertFalse(out["comparison_complete"]);self.assertIsNone(out["candidate"])

    def test_context_difference_is_not_comparable(self):
        def edit(i,p): p["event"]["interaction_context"]["territory_id"]="other" if i==2 else "north_grove"
        out=evaluate(fixture(edits=edit))
        self.assertEqual(out["status"],"not_comparable")
        self.assertIn("context_difference",out["reasons"])
        self.assertFalse(out["comparison_complete"]);self.assertEqual(out["pair_results"],[])

    def test_all_zero_and_all_filtered_are_no_candidate_synthetic(self):
        for magnitude,reason in ((0,"raw_zero"),(1,"neural_filtered")):
            c=fixture(s=1,t=3,edits=lambda i,p:synthetic_dimensions(magnitude))
            out=evaluate(c);self.assertEqual(out["status"],"no_candidate")
            self.assertTrue(out["comparison_complete"])
            self.assertEqual(len(out["selected_projections"]),3)
            self.assertEqual({u["reason"] for r in out["relation_results"] for u in r["unsupported"]},{reason})

    def test_three_matches_plus_filtered_fourth_is_not_unanimous(self):
        def edit(i,p):
            if i==3: p["outcome_facts"]["reward_value"]="NORMAL"
            else: p["outcome_facts"]["reward_value"]="HIGH"
        out=evaluate(fixture(4,s=1,t=3,edits=edit))
        self.assertNotIn("reward_value",names(out))
        reward=next(r for r in out["relation_results"] if r["relation"]=="reward_value")
        self.assertEqual(reward["support_groups"][0]["support_count"],3)
        self.assertEqual(reward["unsupported"][0]["projection_reasons"],["sensitivity_filtered","reward_below_threshold"])
        self.assertEqual(out["candidate"]["support_count"],4)

    def test_sign_strength_and_zero_diagnostics_synthetic(self):
        def edit(i,p):
            ds=synthetic_dimensions(3)
            if i==1: ds[0].update(direction="negative",magnitude=2,magnitude_band="MEDIUM")
            if i==2: ds[0].update(direction="neutral",magnitude=0,magnitude_band="ZERO")
            return ds
        out=evaluate(fixture(edits=edit))
        reasons=[d["reason"] for pair in out["pair_results"] for r in pair["relations"] if r["relation"]=="acquisition" for d in r["reasons"]]
        self.assertIn("strength_difference",reasons);self.assertIn("direction_conflict",reasons);self.assertIn("raw_zero",reasons)
        self.assertNotIn("acquisition",names(out))
        self.assertTrue(any({d["reason"] for d in r["reasons"]}=={"strength_difference","direction_conflict"}
                            for pair in out["pair_results"] for r in pair["relations"]))

    def test_request_type_reference_and_scope_rejections(self):
        c=fixture();m=c.sleep_materials("npc_a")
        for key,value in [("run_id","wrong"),("agent_id","npc_b"),("parameter_id","wrong"),
                          ("parameter_revision",True),("formation_tick",False),("formation_tick",-1),
                          ("rule_version","wrong"),("sleep_cycle",""),("source_experience_ids",["missing"])]:
            r=request(c);r[key]=value
            with self.subTest(key=key,value=value),self.assertRaises(NeuralCandidateError): build(m,r)
        r=request(c);r["extra"]=True
        with self.assertRaises(NeuralCandidateError): build(m,r)
        r=request(c);r["source_experience_ids"]*=2
        with self.assertRaises(NeuralCandidateError): build(m,r)

    def test_budget_before_duplicate_handling_and_upstream_limit(self):
        c=fixture(7);r=request(c)
        with self.assertRaisesRegex(NeuralCandidateError,"selection_budget"): build(c.sleep_materials("npc_a"),r)
        r["source_experience_ids"]=[r["source_experience_ids"][0]]*7
        with self.assertRaisesRegex(NeuralCandidateError,"selection_budget"): build(c.sleep_materials("npc_a"),r)
        c=fixture(9);r=request(c);r["source_experience_ids"]=r["source_experience_ids"][:3]
        with self.assertRaisesRegex(NeuralCandidateError,"sleep_bias_budget"): build(c.sleep_materials("npc_a"),r)

    def test_unselected_invalid_material_is_not_ignored(self):
        c=fixture(4);r=request(c);r["source_experience_ids"]=r["source_experience_ids"][:3]
        m=c.sleep_materials("npc_a");m["biases"][-1]["magnitude"]=99
        with self.assertRaises(NeuralCandidateError): build(m,r)

    def test_material_schema_tampering_and_missing_bias_rejected(self):
        c=fixture();original=c.sleep_materials("npc_a")
        edits=[lambda m:m.update(schema="old"),lambda m:m.update(run_id="other"),
               lambda m:m["biases"].pop(),lambda m:m["projections"][0]["parameter"].update(reward_threshold=3),
               lambda m:m["projections"].append(m["projections"][0])]
        for edit in edits:
            m=copy.deepcopy(original);edit(m)
            with self.assertRaises(NeuralCandidateError): build(m,request(c))

    def test_reference_traceability_and_order_invariance(self):
        c=fixture();m=c.sleep_materials("npc_a");r=request(c);out=build(m,r);candidate=out["candidate"]
        self.assertEqual(set(candidate["source_projection_ids"]),{p["projection_id"] for p in m["projections"]})
        self.assertEqual(set(candidate["source_bias_ids"]),{b["bias_id"] for b in m["biases"]})
        self.assertEqual(set(candidate["source_gradient_ids"]),{p["source_gradient_id"] for p in m["projections"]})
        self.assertEqual(candidate["parameter"],m["parameter"])
        m["projections"].reverse();m["biases"].reverse();r["source_experience_ids"].reverse()
        self.assertEqual(out,build(m,r))

    def test_no_mutable_alias(self):
        c=fixture();m=c.sleep_materials("npc_a");r=request(c);before=copy.deepcopy((m,r));out=build(m,r)
        self.assertEqual((m,r),before)
        out["selected_projections"][0]["raw_record"].clear();out["candidate"]["parameter"].clear()
        self.assertEqual((m,r),before)

    def test_existing_t1_rejects_candidate(self):
        out=evaluate(fixture())
        with self.assertRaises(LocalBiasT1ProjectionError): project_local_bias_candidate(out["candidate"])

    def test_calls_do_not_change_store_actions_or_canonical(self):
        def run(enabled):
            c=fixture();history=InteractionHistory();canonical=GameAIFrozenComparisonSidecar();actions=[]
            for i in range(3):
                if enabled: evaluate(c)
                obs=packet(f"n4-{i}",tick=i+1);action=decide_action(obs);actions.append(action)
                history.register_decision(obs,action);canonical.capture(obs)
            return c.snapshot(),actions,history.snapshot(),canonical.snapshot()
        self.assertEqual(run(True),run(False))


if __name__=="__main__": unittest.main()
