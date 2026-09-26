import copy
from dataclasses import FrozenInstanceError, asdict
import unittest
from unittest.mock import patch

from runtime.neural_gradient import (NeuralParameter, NeuralInputError, RULE, RELATIONS, BANDS,
    project_perceived_gradient as project, preview_neural_bias as preview, replay_neural_gradients as replay)
from runtime.outcome_bias import OutcomeGradientStore, LocalBiasStore, OutcomeBiasError
from runtime.luanti_outcome import LuantiOutcomeCoordinator
from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_outcome_bias import source
from test_luanti_outcome import attack_payload
from test_sensory_observation import packet


def parameter(s=3,t=0,agent="npc_a",pid="p"):
    return NeuralParameter(agent,pid,1,s,t)


def fixture(agent="npc_a",reward="NORMAL"):
    store=OutcomeGradientStore()
    experience=source(agent,True)
    store.form(experience,{"food_acquired":True,"returned_to_base":True,"injury_level":"light","reward_value":reward})
    snapshot={"run_id":"replay-1","gradients":store.snapshot()}
    r={"run_id":"replay-1","agent_id":agent,"source_gradient_id":snapshot["gradients"]["records"][0]["gradient_id"],"rule_version":RULE}
    return snapshot,r


def by_relation(projected):
    return {d["relation"]:d for d in projected["dimensions"]}


class NeuralGradientTests(unittest.TestCase):
    def test_four_corners_from_existing_store(self):
        s,r=fixture();before=copy.deepcopy(s)
        for sensitivity,threshold in ((1,1),(1,3),(3,1),(3,3)):
            out=by_relation(project(s,r,parameter(sensitivity,threshold)))
            self.assertEqual(out["reward_value"]["magnitude"],2 if (sensitivity,threshold)==(3,1) else 0)
            self.assertEqual(out["injury"]["magnitude"],1 if sensitivity==3 else 0)
            self.assertEqual(out["acquisition"]["magnitude"],3)
            hi,req=fixture(reward="HIGH")
            self.assertEqual(by_relation(project(hi,req,parameter(sensitivity,threshold)))["reward_value"]["magnitude"],3)
        self.assertEqual(s,before)

    def test_exhaustive_ordinal_table_synthetic_384_cases(self):
        # Synthetic boundary records, including reward=1 absent from the raw generator.
        for relation in RELATIONS:
            for direction in ("positive","negative"):
                for magnitude in range(4):
                    for sensitivity in (1,2,3):
                        for threshold in range(4):
                            s,r=fixture();d=next(d for d in s["gradients"]["records"][0]["dimensions"] if d["relation"]==relation)
                            d.update(magnitude=magnitude,magnitude_band=BANDS[magnitude],direction=direction if magnitude else "neutral")
                            out=by_relation(project(s,r,parameter(sensitivity,threshold)))[relation]
                            expected=magnitude if magnitude in {1:{3},2:{2,3},3:{1,2,3}}[sensitivity] else 0
                            if relation=="reward_value" and direction=="positive" and magnitude<threshold: expected=0
                            self.assertEqual(out["magnitude"],expected)
                            self.assertEqual(out["raw"],d)
                            self.assertEqual(out["direction"],direction if expected else "neutral")

    def test_both_reasons_and_zero(self):
        s,r=fixture();out=by_relation(project(s,r,parameter(1,3)))
        self.assertEqual(out["reward_value"]["reasons"],["sensitivity_filtered","reward_below_threshold"])
        s,r=fixture(reward="ZERO")
        self.assertEqual(by_relation(project(s,r,parameter(1,3)))["reward_value"]["reasons"],["raw_zero"])

    def test_parameter_is_frozen_and_strict(self):
        p=parameter()
        with self.assertRaises(FrozenInstanceError): p.error_sensitivity=1
        for key,values in {"revision":[True,1.0,2],"error_sensitivity":[True,1.0,0,4,float("nan")],"reward_threshold":[False,0.0,-1,4],"agent_id":["",None,"x"*129]}.items():
            for value in values:
                d=asdict(p);d[key]=value
                with self.subTest(key=key,value=value),self.assertRaises(NeuralInputError): NeuralParameter.parse(d)
        d=asdict(p);d["extra"]=0
        with self.assertRaises(NeuralInputError): NeuralParameter.parse(d)

    def test_reference_and_rule_rejections(self):
        for key,value in [("run_id","old"),("rule_version","wrong"),("agent_id","npc_b"),("source_gradient_id","missing")]:
            s,r=fixture();r[key]=value
            with self.assertRaises(NeuralInputError): project(s,r,parameter())
        s,r=fixture()
        with self.assertRaises(NeuralInputError): project(s,r,parameter(agent="npc_b"))
        s["gradients"]["records"].append(copy.deepcopy(s["gradients"]["records"][0]))
        with self.assertRaises(NeuralInputError): project(s,r,parameter())

    def test_malformed_dimensions_rejected(self):
        for change in (lambda ds:ds.pop(),lambda ds:ds.append(ds[0]),lambda ds:ds.__setitem__(1,ds[0]),
                       lambda ds:ds[0].update(magnitude=True),lambda ds:ds[0].update(magnitude_band="ZERO"),
                       lambda ds:ds[0].update(direction="neutral"),lambda ds:ds[0].update(extra=0)):
            s,r=fixture();change(s["gradients"]["records"][0]["dimensions"])
            with self.assertRaises(NeuralInputError): project(s,r,parameter())
        s,r=fixture();s["gradients"]["records"][0]["schema"]="unknown"
        with self.assertRaises(NeuralInputError): project(s,r,parameter())

    def test_identity_and_order_independence(self):
        s,r=fixture();a=project(s,r,parameter())
        self.assertEqual(a,project(s,r,parameter()))
        s["gradients"]["records"][0]["dimensions"].reverse()
        self.assertEqual(a,project(s,r,parameter()))
        for p in (parameter(2),parameter(t=1),parameter(pid="other")):
            self.assertNotEqual(a["projection_id"],project(s,r,p)["projection_id"])

    def test_preview_neutral_matches_existing_bias_values(self):
        s,r=fixture();raw=s["gradients"]["records"][0]
        standard=LocalBiasStore().form(raw);shadow=preview(project(s,r,parameter()))["biases"]
        values=lambda xs:[(x["relation"],x["direction"],x["strength"],x["magnitude"]) for x in xs]
        self.assertEqual(values(standard),values(shadow))
        self.assertNotEqual(standard[0]["schema"],shadow[0]["schema"])
        with self.assertRaises(OutcomeBiasError): LocalBiasStore().form(project(s,r,parameter()))

    def test_preview_rejects_tampering_and_wrong_schema(self):
        s,r=fixture();p=project(s,r,parameter())
        for modify in (lambda x:x.update(schema="wrong"),lambda x:x["dimensions"][0].update(magnitude=0),
                       lambda x:x.update(projection_id="wrong"),lambda x:x.update(extra=True)):
            v=copy.deepcopy(p);modify(v)
            with self.assertRaises(NeuralInputError): preview(v)

    def test_empty_preview_is_valid_not_missing_data(self):
        s,r=fixture()
        for d in s["gradients"]["records"][0]["dimensions"]:
            d.update(magnitude=0,magnitude_band="ZERO",direction="neutral")
        self.assertEqual(preview(project(s,r,parameter()))["biases"],[])

    def test_output_does_not_alias_inputs(self):
        s,r=fixture();before=copy.deepcopy((s,r));p=project(s,r,parameter());b=preview(p)
        b["biases"][0]["source_world_event_ids"].clear()
        self.assertTrue(p["source_world_event_ids"])
        p["raw_record"]["dimensions"].clear();p["parameter"].clear()
        self.assertEqual((s,r),before)

    def test_two_agents_and_parameter_order(self):
        a,ra=fixture();b,rb=fixture("npc_b")
        self.assertEqual(a["gradients"]["records"][0]["dimensions"],b["gradients"]["records"][0]["dimensions"])
        self.assertNotEqual(ra["source_gradient_id"],rb["source_gradient_id"])
        self.assertNotEqual(a["gradients"]["records"][0]["source_world_event_ids"],b["gradients"]["records"][0]["source_world_event_ids"])
        a["gradients"]["records"]+=b["gradients"]["records"]
        ps=[parameter(1,3,pid="a"),parameter(3,1,agent="npc_b",pid="b")]
        qs=[{"parameter_id":"a","request":ra},{"parameter_id":"b","request":rb}]
        x=replay(a,ps,qs)
        self.assertEqual(x,replay(a,list(reversed(ps)),qs))
        self.assertEqual(x,list(reversed(replay(a,ps,list(reversed(qs))))))
        self.assertNotEqual(x[0]["perceived"]["dimensions"],x[1]["perceived"]["dimensions"])

    def test_runner_limits_and_frozen_assignment(self):
        s,r=fixture();q={"parameter_id":"p","request":r}
        self.assertEqual(len(replay(s,[parameter()],[q]*64)),64)
        with self.assertRaises(NeuralInputError): replay(s,[parameter()],[q]*65)
        ps=[parameter(agent=f"a{i}",pid=f"p{i}") for i in range(16)]
        self.assertEqual(replay(s,ps,[]),[])
        with self.assertRaises(NeuralInputError): replay(s,ps+[parameter()],[])
        with self.assertRaises(NeuralInputError): replay(s,[parameter(),parameter(1,pid="new")],[])
        records=s["gradients"]["records"]
        for i in range(127):
            item=copy.deepcopy(records[0]);item["gradient_id"]=f"other-{i}";records.append(item)
        self.assertEqual(len(replay(s,[parameter()],[q])),1)
        records.append(copy.deepcopy(records[0]))
        with self.assertRaises(NeuralInputError): replay(s,[parameter()],[q])

    def test_runner_validates_all_before_projecting(self):
        s,r=fixture();bad=copy.deepcopy(r);bad["source_gradient_id"]="absent"
        with patch("runtime.neural_gradient._project") as mocked:
            with self.assertRaises(NeuralInputError): replay(s,[parameter()],[{"parameter_id":"p","request":r},{"parameter_id":"p","request":bad}])
            mocked.assert_not_called()

    def test_existing_actions_learning_sleep_canonical_unchanged(self):
        def run(enabled):
            coordinator=LuantiOutcomeCoordinator();history=InteractionHistory();canonical=GameAIFrozenComparisonSidecar();actions=[]
            for i in range(3):
                record=coordinator.record(attack_payload(i))
                if enabled:
                    snapshot={"run_id":"r","gradients":coordinator.gradients.snapshot()}
                    request={"run_id":"r","agent_id":"npc_a","source_gradient_id":record["gradient"]["gradient_id"],"rule_version":RULE}
                    preview(project(snapshot,request,parameter(1,3)))
                observed=packet(f"fixed-{i}",tick=i+1);action=decide_action(observed)
                actions.append(action);history.register_decision(observed,action);canonical.capture(observed)
            sleep=coordinator.consolidate({"agent_id":"npc_a","sleep_cycle":"nerv-check","formation_tick":40})
            return actions,history.snapshot(),coordinator.snapshot(),sleep,canonical.snapshot()
        self.assertEqual(run(False),run(True))


if __name__=="__main__": unittest.main()
