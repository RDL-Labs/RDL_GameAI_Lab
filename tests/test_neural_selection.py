import copy
import json
import unittest
from unittest.mock import patch

from runtime.neural_selection import (evaluate_neural_t1_selection as evaluate,
    record_neural_t1_selection as record, NeuralSelectionError, TARGET_SCHEMA, DIMENSION)
from runtime.neural_t1 import expand_neural_t1_materials
from runtime.neural_candidate import NeuralCandidateError
from runtime.t1_material_selection import T1MaterialSelectionLedger, T1MaterialSelectionError
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from test_neural_candidate import fixture, request
from test_neural_outcome import synthetic_dimensions
from test_neural_t1 import canonical
from test_sensory_observation import packet


def setup(count=6, edits=None, mapped=True, sensitivity=3):
    c=fixture(count,s=sensitivity,edits=edits)
    m=c.sleep_materials("npc_a");r=request(c);r["source_experience_ids"]=r["source_experience_ids"][:3]
    sidecar,state,model,path,binding=canonical()
    if mapped:
        # Explicit synthetic Food target declaration; no live canonical interpreter is changed.
        model["boundary"]["dimensions"].append(DIMENSION)
        model["coefficients"][DIMENSION]=1.0;model["biases"][DIMENSION]=0.0
    out=expand_neural_t1_materials(m,r,binding,state,model,path,sidecar.t1_materials)
    target={"schema":TARGET_SCHEMA,"model_ref":binding["model_ref"],
            "boundary_ref":binding["boundary_ref"],"criteria_ref":binding["criteria_ref"],
            "target_dimension":DIMENSION,"relation":"acquisition",
            "context_signature":copy.deepcopy(m["projections"][0]["raw_record"]["context_signature"]),
            "positive_meaning":"food_acquired","negative_meaning":"food_not_acquired","allowed_mismatches":0}
    return c,sidecar,dict(bundle=out["bundle"],materials=m,candidate_request=r,
        validation_experience_ids=[p["source_experience_id"] for p in m["projections"][3:]],model=model,target=target)


def acquisition(result,kw):
    mid=next(m["material_id"] for m in kw["bundle"]["materials"] if m["kind"]=="CandidateRelation"
             and m["payload"]["common_relation_signature"]["relation"]=="acquisition")
    return next(d for d in result["decisions"] if d["material_id"]==mid)


def negative(i,p):
    p["outcome_facts"].update(food_acquired=False,reward_value="ZERO")


class NeuralSelectionTests(unittest.TestCase):
    def test_positive_and_negative_recurrence_retain(self):
        for edit in (None,negative):
            _,_,kw=setup(edits=edit);out=evaluate(**kw);d=acquisition(out,kw)
            self.assertEqual(d["disposition"],"RETAIN");self.assertTrue(d["comparison_complete"])
            self.assertEqual((d["formation_support_count"],d["validation_count"]),(3,3))
            for p in d["pair_results"]: self.assertEqual(p["raw_dimension"],p["neural_dimension"]["raw"])

    def test_counterexample_both_directions_reject(self):
        for formation_negative in (False,True):
            def edit(i,p):
                if (i<3)==formation_negative: negative(i,p)
            _,_,kw=setup(edits=edit);d=acquisition(evaluate(**kw),kw)
            self.assertEqual(d["disposition"],"REJECT");self.assertTrue(d["comparison_complete"])

    def test_missing_mapping_and_no_validation_defer_multiple_reasons(self):
        _,_,kw=setup(count=3,mapped=False);d=acquisition(evaluate(**kw),kw)
        self.assertEqual(d["disposition"],"DEFER")
        self.assertEqual(set(d["reasons"]),{"target_mapping_unavailable","no_validation_experience"})
        _,_,kw=setup();kw["target"]=None
        self.assertIn("target_mapping_unavailable",acquisition(evaluate(**kw),kw)["reasons"])

    def test_counterexample_plus_incomparable_defers_but_keeps_pair(self):
        def edit(i,p):
            if i==3: negative(i,p)
            if i==4:p["event"]["interaction_context"]["territory_id"]="elsewhere"
        _,_,kw=setup(edits=edit);d=acquisition(evaluate(**kw),kw)
        self.assertEqual(d["disposition"],"DEFER");self.assertFalse(d["comparison_complete"])
        self.assertTrue(any(p["matched"] is False for p in d["pair_results"]))
        self.assertTrue(any("validation_context_mismatch" in p["reasons"] for p in d["pair_results"]))

    def test_other_relations_and_canonical_defer(self):
        _,_,kw=setup();out=evaluate(**kw)
        self.assertEqual(sum(d["disposition"]=="RETAIN" for d in out["decisions"]),1)
        self.assertEqual(sum(d["reasons"]==["canonical_material_out_of_scope"] for d in out["decisions"]),4)
        self.assertEqual(sum(d["reasons"]==["relation_out_of_scope"] for d in out["decisions"]),3)

    def test_filtered_relation_not_resurrected(self):
        _,_,kw=setup(sensitivity=1);out=evaluate(**kw)
        self.assertEqual(len(out["decisions"]),6)
        self.assertEqual(len(out["source_result"]["relation_results"]),4)
        self.assertTrue(any(r["unsupported"] for r in out["source_result"]["relation_results"]))

    def test_unknown_duplicate_and_formation_overlap(self):
        _,_,kw=setup()
        for ids in (["unknown"],kw["validation_experience_ids"]*2,kw["candidate_request"]["source_experience_ids"][:1]):
            with self.assertRaises(NeuralSelectionError):evaluate(**dict(kw,validation_experience_ids=ids))

    def test_same_event_distinct_experience_rejected(self):
        from runtime.neural_gradient import _project, NeuralParameter
        from runtime.neural_outcome import _form_biases
        _,_,kw=setup();m=copy.deepcopy(kw["materials"])
        original=m["projections"][3];raw=copy.deepcopy(original["raw_record"])
        raw["source_world_event_ids"]=m["projections"][0]["source_world_event_ids"][:]
        new=_project(raw,NeuralParameter.parse(m["parameter"]),m["run_id"])
        m["projections"][3]=new
        m["biases"]=[b for b in m["biases"] if b["source_projection_id"]!=original["projection_id"]]+_form_biases(new)
        with self.assertRaisesRegex(NeuralSelectionError,"event_overlap"):evaluate(**dict(kw,materials=m))

    def test_tampering_model_target_bundle_and_materials(self):
        _,_,kw=setup()
        for field,edit in [("model",lambda x:x.update(model_ref="old")),
                           ("target",lambda x:x.update(criteria_ref="wrong")),
                           ("target",lambda x:x.update(allowed_mismatches=True)),
                           ("bundle",lambda x:x["materials"][-1]["payload"].update(support_count=9)),
                           ("materials",lambda x:x["biases"][-1].update(magnitude=99))]:
            changed=copy.deepcopy(kw[field]);edit(changed)
            with self.subTest(field=field),self.assertRaises((NeuralSelectionError,NeuralCandidateError)):
                evaluate(**dict(kw,**{field:changed}))

    def test_acquisition_raw_zero_is_rule_error_not_negative_evidence(self):
        # A coherent neural projection over synthetic raw zero is still not a
        # valid output of the declared boolean-acquisition adapter.
        _,_,kw=setup(edits=lambda i,p:synthetic_dimensions(0) if i==5 else None)
        with self.assertRaisesRegex(NeuralSelectionError,"acquisition_rule_inconsistent"):evaluate(**kw)

    def test_budget_and_upstream_capacity(self):
        _,_,kw=setup(9,sensitivity=1);out=evaluate(**kw)
        self.assertEqual(acquisition(out,kw)["validation_count"],6)
        with self.assertRaisesRegex(NeuralSelectionError,"validation_budget"):
            evaluate(**dict(kw,validation_experience_ids=[kw["validation_experience_ids"][0]]*7))
        _,_,base=setup()
        c=fixture(9);m=c.sleep_materials("npc_a")
        with self.assertRaisesRegex(NeuralCandidateError,"sleep_bias_budget"):evaluate(**dict(base,materials=m))

    def test_order_determinism_and_no_alias(self):
        _,_,kw=setup();before=copy.deepcopy(kw);out=evaluate(**kw)
        kw["validation_experience_ids"].reverse();kw["materials"]["projections"].reverse()
        kw["materials"]["biases"].reverse();kw["candidate_request"]["source_experience_ids"].reverse()
        kw["bundle"]["materials"].reverse()
        self.assertEqual(out,evaluate(**kw))
        changed=copy.deepcopy(kw);out["source_result"].clear();out["validation_projections"][0].clear()
        self.assertEqual(kw,changed)
        self.assertEqual(before["model"],kw["model"])

    def test_record_all_materials_diagnostics_and_revision(self):
        _,sidecar,kw=setup();ledger=sidecar.t1_selection
        out=record(ledger=ledger,reviewer="fixture",expected_revision=0,**kw)
        self.assertEqual(out["record"]["counts"],{"RETAIN":1,"REJECT":0,"DEFER":7})
        for m in out["record"]["materials"]:self.assertEqual(json.loads(m["evidence"]),out["evaluation"])
        before=ledger.snapshot()
        with self.assertRaises(T1MaterialSelectionError):record(ledger=ledger,reviewer="fixture",expected_revision=0,**kw)
        self.assertEqual(ledger.snapshot(),before)
        new=record(ledger=ledger,reviewer="fixture",expected_revision=1,**kw)
        self.assertEqual(new["record"]["revision"],2);self.assertEqual(out["evaluation"],new["evaluation"])

    def test_capacity_and_invalid_review_no_partial_update(self):
        _,_,kw=setup();ledger=T1MaterialSelectionLedger(capacity=1)
        # Fill the generic ledger with a distinct explicit bundle for capacity testing.
        other=copy.deepcopy(kw["bundle"]);other["bundle_id"]="other"
        ledger.inspect(other,{"expected_revision":0,"reviewer":"fixture","materials":[
            {"material_id":m["material_id"],"disposition":"DEFER","basis":"fixture","evidence":"fixture"}
            for m in other["materials"]]})
        before=ledger.snapshot();out=record(ledger=ledger,reviewer="fixture",expected_revision=0,**kw)
        self.assertEqual(out["status"],"capacity_rejected");self.assertIsNone(out["record"])
        self.assertEqual(ledger.snapshot()["records"],before["records"])
        empty=T1MaterialSelectionLedger()
        with self.assertRaises(T1MaterialSelectionError):record(ledger=empty,reviewer="",expected_revision=0,**kw)
        self.assertEqual(empty.snapshot()["count"],0)

    def test_only_selection_changes_no_action_or_reconstruction(self):
        def run(enabled):
            c,sidecar,kw=setup();before=sidecar.snapshot();neural=c.snapshot()
            if enabled:
                evaluate(**kw);self.assertEqual(sidecar.snapshot(),before)
                with patch.object(sidecar.t1_reconstruction,"reconstruct",side_effect=AssertionError("must not reconstruct")):
                    record(ledger=sidecar.t1_selection,reviewer="fixture",expected_revision=0,**kw)
                self.assertEqual(c.snapshot(),neural)
            history=InteractionHistory();actions=[]
            for i in range(3):
                obs=packet(f"n4c-{i}",tick=i+1);action=decide_action(obs);actions.append(action);history.register_decision(obs,action)
            snap=sidecar.snapshot();snap.pop("T1_selection")
            return c.snapshot(),snap,actions,history.snapshot()
        self.assertEqual(run(True),run(False))


if __name__=="__main__":unittest.main()
