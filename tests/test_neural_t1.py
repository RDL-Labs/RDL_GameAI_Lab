import copy
import unittest

from runtime.neural_t1 import (prepare_neural_t1_materials as prepare,
                               expand_neural_t1_materials as expand, NeuralT1Error, PURPOSE)
from runtime.neural_candidate import NeuralCandidateError
from runtime.t1_material_expansion import T1MaterialExpansionStore, T1MaterialExpansionError
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from test_neural_candidate import fixture, request
from test_neural_outcome import synthetic_dimensions
from test_t1_material_expansion import reviewed_sidecar, candidate
from test_sensory_observation import packet


def canonical():
    sidecar, assessment = reviewed_sidecar()
    snap = sidecar.snapshot()
    path = next(p for p in snap["review_path"]["paths"] if p["assessment_id"] == assessment)
    state = next(s for s in snap["M_delta"]["states"] if s["model_ref"] == path["model_ref"])
    model = snap["models"][path["model_ref"]]
    binding = {"run_id": "r", "agent_id": "npc_a", "transition_id": state["transition"]["transition_id"],
               "model_ref": model["model_ref"], "assessment_id": assessment,
               "purpose": PURPOSE, "boundary_ref": "nerv4b-fixture-boundary", "criteria_ref": "nerv4b-inspection-only"}
    return sidecar, state, model, path, binding


def inputs(c=None):
    c = c or fixture()
    sidecar, state, model, path, binding = canonical()
    return c, sidecar, dict(materials=c.sleep_materials("npc_a"), candidate_request=request(c),
                           binding=binding, m_delta_state=state, model=model, review_path=path,
                           store=sidecar.t1_materials)


class NeuralT1Tests(unittest.TestCase):
    def test_four_corners_materials_and_dependent_evidence(self):
        for s, t, count in ((1,1,2),(1,3,2),(3,1,4),(3,3,3)):
            c=fixture(s=s,t=t); out=prepare(c.sleep_materials("npc_a"),request(c))
            self.assertEqual(len(out["children"]),count)
            for child in out["children"]:
                self.assertEqual(child["support_count"],3)
                self.assertEqual(len(child["evidence_pairs"]),3)
                self.assertEqual(child["parameter"],out["source_result"]["parameter"])
                for pair in child["evidence_pairs"]:
                    self.assertEqual(pair["raw_dimension"],pair["neural_dimension"]["raw"])
                    self.assertIn("not-independent-votes",pair["dependency"])

    def test_filtered_fourth_is_preserved_not_resurrected(self):
        def edit(i,p): p["outcome_facts"]["reward_value"]="NORMAL" if i==3 else "HIGH"
        c=fixture(4,s=1,t=3,edits=edit); out=prepare(c.sleep_materials("npc_a"),request(c))
        self.assertNotIn("reward_value",[x["common_relation_signature"]["relation"] for x in out["children"]])
        reward=next(r for r in out["source_result"]["relation_results"] if r["relation"]=="reward_value")
        self.assertEqual(reward["support_groups"][0]["support_count"],3)
        self.assertEqual(reward["unsupported"][0]["reason"],"neural_filtered")

    def test_no_material_states_do_not_expand(self):
        def context(i,p): p["event"]["interaction_context"]["territory_id"]=str(i)
        cases=[(fixture(2),"insufficient_experiences"),(fixture(edits=context),"not_comparable")]
        for magnitude in (0,1):
            cases.append((fixture(s=1,t=3,edits=lambda i,p:synthetic_dimensions(magnitude)),"no_candidate"))
        for c, status in cases:
            _,sidecar,kw=inputs(c);before=sidecar.snapshot();out=expand(**kw)
            self.assertEqual(out["status"],"no_inspection_materials")
            self.assertEqual(out["preparation"]["source_result"]["status"],status)
            self.assertEqual(out["preparation"]["children"],[]);self.assertIsNone(out["bundle"])
            self.assertEqual(sidecar.snapshot(),before)

    def test_invalid_sources_rejected_before_store_mutation(self):
        c,sidecar,kw=inputs(fixture(4));kw["candidate_request"]["source_experience_ids"]=kw["candidate_request"]["source_experience_ids"][:3]
        for edit in (lambda m:m["biases"][-1].update(magnitude=99),lambda m:m["biases"].pop(),
                     lambda m:m.update(schema="old"),lambda m:m.update(agent_id="npc_b")):
            material=copy.deepcopy(kw["materials"]);edit(material);before=sidecar.snapshot()
            with self.assertRaises(NeuralCandidateError): expand(**dict(kw,materials=material))
            self.assertEqual(sidecar.snapshot(),before)
        with self.assertRaises(NeuralCandidateError): prepare({"candidate_id":"forged"},request(c))

    def test_budgets_order_and_alias(self):
        c=fixture(6);m=c.sleep_materials("npc_a");r=request(c);before=copy.deepcopy((m,r))
        out=prepare(m,r);self.assertEqual(len(out["children"]),4)
        self.assertTrue(all(x["support_count"]==6 for x in out["children"]))
        m["projections"].reverse();m["biases"].reverse();r["source_experience_ids"].reverse()
        self.assertEqual(out,prepare(m,r))
        out["children"][0]["evidence_pairs"][0]["raw_dimension"].clear()
        out["source_result"]["parameter"].clear()
        m["projections"].reverse();m["biases"].reverse();r["source_experience_ids"].reverse()
        self.assertEqual((m,r),before)
        for n in (7,9):
            c=fixture(n);r=request(c)
            if n==9:r["source_experience_ids"]=r["source_experience_ids"][:3]
            with self.assertRaises(NeuralCandidateError):prepare(c.sleep_materials("npc_a"),r)

    def test_binding_rejections_preserve_store(self):
        _,sidecar,kw=inputs();before=sidecar.snapshot()
        for field in kw["binding"]:
            b=copy.deepcopy(kw["binding"]);b[field]="" if field in ("boundary_ref","criteria_ref") else "wrong"
            with self.subTest(field=field),self.assertRaises(NeuralT1Error):expand(**dict(kw,binding=b))
            self.assertEqual(sidecar.snapshot(),before)
        b=copy.deepcopy(kw["binding"]);b["extra"]=True
        with self.assertRaises(NeuralT1Error):expand(**dict(kw,binding=b))

    def test_inactive_and_inconsistent_canonical_sources_rejected(self):
        _,sidecar,kw=inputs();before=sidecar.snapshot()
        for name, field, value in (("m_delta_state","phase","NORMAL"),
                                   ("model","model_ref","old"),("review_path","assessment_id","old"),
                                   ("review_path","agent_id","npc_b")):
            changed=copy.deepcopy(kw[name]);changed[field]=value
            with self.assertRaises(T1MaterialExpansionError):expand(**dict(kw,**{name:changed}))
            self.assertEqual(sidecar.snapshot(),before)

    def test_expansion_is_uninspected_and_parent_traceable(self):
        c,sidecar,kw=inputs();before=sidecar.snapshot();neural=c.snapshot();out=expand(**kw)
        self.assertEqual(out["status"],"expanded_for_inspection")
        bundle=out["bundle"];self.assertEqual(bundle["counts"],{"canonical":4,"candidates":4,"experiences":0})
        self.assertTrue(all(x["disposition"]=="UNINSPECTED" for x in bundle["materials"]))
        for x in bundle["materials"][4:]:
            self.assertEqual(x["payload"]["source_result"],out["preparation"]["source_result"])
            self.assertEqual(x["payload"]["binding"],kw["binding"])
        after=sidecar.snapshot();before.pop("T1_materials");after.pop("T1_materials")
        self.assertEqual(before,after);self.assertEqual(c.snapshot(),neural)
        saved=sidecar.t1_materials.snapshot();bundle["materials"][-1]["payload"]["source_result"].clear()
        self.assertEqual(sidecar.t1_materials.snapshot(),saved)

    def test_replay_and_binding_change_conflict(self):
        _,sidecar,kw=inputs();first=expand(**kw);saved=sidecar.snapshot()
        self.assertEqual(expand(**kw),first);self.assertEqual(sidecar.snapshot(),saved)
        for change in ("criteria_ref","boundary_ref"):
            b=copy.deepcopy(kw["binding"]);b[change]="different"
            with self.assertRaisesRegex(T1MaterialExpansionError,"changed frozen"):expand(**dict(kw,binding=b))
            self.assertEqual(sidecar.snapshot(),saved)
        r=copy.deepcopy(kw["candidate_request"]);r["sleep_cycle"]="new"
        with self.assertRaises(T1MaterialExpansionError):expand(**dict(kw,candidate_request=r))
        self.assertEqual(sidecar.snapshot(),saved)

    def test_existing_legacy_bundle_not_replaced(self):
        _,sidecar,kw=inputs()
        sidecar.t1_materials.expand(m_delta_state=kw["m_delta_state"],model=kw["model"],
                                    review_path=kw["review_path"],candidates=[candidate()])
        before=sidecar.snapshot()
        with self.assertRaises(T1MaterialExpansionError):expand(**kw)
        self.assertEqual(sidecar.snapshot(),before)

    def test_capacity_rejection_and_replay_at_capacity(self):
        _,_,kw=inputs();store=T1MaterialExpansionStore(capacity=1);kw["store"]=store
        first=expand(**kw);self.assertEqual(expand(**kw),first)
        state=copy.deepcopy(kw["m_delta_state"]);state["transition"]["transition_id"]="second-transition"
        b=copy.deepcopy(kw["binding"]);b["transition_id"]="second-transition"
        before=store.snapshot();out=expand(**dict(kw,m_delta_state=state,binding=b))
        self.assertEqual(out["status"],"capacity_rejected");self.assertIsNone(out["bundle"])
        after=store.snapshot();self.assertEqual(after["bundles"],before["bundles"])
        self.assertEqual(after["count"],1);self.assertEqual(after["capacity_rejections"],1)

    def test_preparation_and_expansion_leave_actions_and_legacy_state_unchanged(self):
        def run(enabled):
            c,sidecar,kw=inputs();history=InteractionHistory();actions=[]
            before=sidecar.snapshot()
            if enabled:
                prepare(kw["materials"],kw["candidate_request"])
                self.assertEqual(sidecar.snapshot(),before)
                expand(**kw)
            for i in range(3):
                obs=packet(f"n4b-{i}",tick=i+1);action=decide_action(obs);actions.append(action)
                history.register_decision(obs,action)
            snap=sidecar.snapshot();snap.pop("T1_materials")
            return c.snapshot(),actions,history.snapshot(),snap
        self.assertEqual(run(True),run(False))


if __name__ == "__main__":
    unittest.main()
