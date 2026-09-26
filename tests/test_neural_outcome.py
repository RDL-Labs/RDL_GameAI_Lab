import copy
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, FrozenInstanceError
import unittest
from unittest.mock import patch

from runtime.neural_outcome import (NeuralOutcomeCoordinator, NeuralAdmissionError,
    compile_neural_sleep_profile, BIAS_SCHEMA, PROFILE_SCHEMA)
from runtime.neural_gradient import NeuralParameter, BANDS
from runtime.luanti_outcome import LuantiOutcomeCoordinator
from runtime.outcome_bias import OutcomeGradientStore
from runtime.territory_experience import TerritoryExperienceStore
from runtime.functions.local_bias_profile import build_local_bias_profiles, LocalBiasProfileError
from runtime.functions.local_bias_deep_similarity import build_local_bias_deep_shadow, LocalBiasDeepSimilarityError
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from runtime.experience import InteractionHistory
from runtime.core import decide_action
from test_luanti_outcome import attack_payload
from test_sensory_observation import packet


def param(agent="npc_a",s=3,t=0):
    return NeuralParameter(agent,"param-"+agent,1,s,t)


def coordinator(s=3,t=0,**kwargs):
    return NeuralOutcomeCoordinator("run-1",[param(s=s,t=t)],**kwargs)


def success(index=0,agent="npc_a"):
    p=attack_payload(index,agent)
    p["event"]["event_id"] += "-"+agent
    p["event"]["world_consequence"]["injury_level"]="light"
    p["outcome_facts"].update(food_acquired=True,returned_to_base=True,injury_level="light",reward_value="NORMAL")
    return p


def values(biases):
    return sorted((b["relation"],b["direction"],b["strength"],b["magnitude"]) for b in biases)


def synthetic_dimensions(m):
    return [{"relation":r,"direction":"neutral" if m==0 else "negative" if r=="injury" else "positive",
             "magnitude":m,"magnitude_band":BANDS[m]} for r in ("acquisition","return","injury","reward_value")]


class NeuralOutcomeTests(unittest.TestCase):
    def test_neutral_matches_raw_bias_values_but_not_schema(self):
        payload=success();old=LuantiOutcomeCoordinator().record(payload);c=coordinator();new=c.record(payload)
        self.assertEqual(old["experience"],new["experience"])
        self.assertEqual(old["gradient"],new["gradient"])
        self.assertEqual(values(old["biases"]),values(new["biases"]))
        self.assertTrue(all(b["schema"]==BIAS_SCHEMA for b in new["biases"]))
        self.assertNotEqual(old["biases"][0]["bias_id"],new["biases"][0]["bias_id"])
        profile=c.build_sleep_profile("npc_a")
        self.assertEqual(profile["profile_count"],1)
        self.assertEqual(values(profile["profiles"][0]["relations"]),values(new["biases"]))

    def test_four_corners_stored_and_raw_unmodified(self):
        raws=[]
        for s,t in ((1,1),(1,3),(3,1),(3,3)):
            c=coordinator(s,t);out=c.record(success());raws.append(out["gradient"])
            bs={b["relation"]:b["magnitude"] for b in out["biases"]}
            self.assertEqual(bs.get("reward_value",0),2 if (s,t)==(3,1) else 0)
            self.assertEqual(bs.get("injury",0),1 if s==3 else 0)
            for b in out["biases"]:
                self.assertEqual(b["source_projection_id"],out["projection"]["projection_id"])
                self.assertEqual(b["parameter"],asdict(param(s=s,t=t)))
                self.assertEqual(b["context_signature"],out["gradient"]["context_signature"])
        self.assertTrue(all(raw==raws[0] for raw in raws))

    def test_exact_replay_at_capacity_and_conflict(self):
        c=coordinator(capacities={"receipts":1,"experiences":1,"gradients":1,"projections":1,"biases":4})
        first=c.record(success());before=c.snapshot();profile=c.build_sleep_profile("npc_a")
        self.assertEqual(c.record(success()),first)
        self.assertEqual(c.snapshot(),before)
        self.assertEqual(c.build_sleep_profile("npc_a"),profile)
        changed=success();changed["outcome_facts"]["reward_value"]="HIGH"
        with self.assertRaisesRegex(NeuralAdmissionError,"event_conflict"): c.record(changed)
        with self.assertRaises(NeuralAdmissionError): c.record(success(1))
        self.assertEqual(c.snapshot(),before)

    def test_each_store_capacity_has_no_partial_commit(self):
        for field in ("receipts","experiences","gradients","projections","biases"):
            with self.subTest(field=field):
                c=coordinator(capacities={field:8 if field=="biases" else 2})
                self.assertEqual(len(c.snapshot()["receipts"]),0)
                c.record(success(0));c.record(success(1));before=c.snapshot()
                with self.assertRaises(NeuralAdmissionError): c.record(success(2))
                self.assertEqual(c.snapshot(),before)
                c.record(success(0));self.assertEqual(c.snapshot(),before)

    def test_insufficient_room_for_all_four_biases_rejects_entire_event(self):
        c=coordinator(capacities={"biases":6});c.record(success());before=c.snapshot()
        with self.assertRaisesRegex(NeuralAdmissionError,"bias_capacity"): c.record(success(1))
        self.assertEqual(c.snapshot(),before)

    def test_default_128_events_and_256_biases_boundary(self):
        c=coordinator(1,3)
        for i in range(128): c.record(success(i))
        before=c.snapshot()
        self.assertEqual(len(before["receipts"]),128)
        self.assertEqual(len(before["experiences"]["records"]),128)
        self.assertEqual(before["gradients"]["count"],128)
        self.assertEqual(len(before["projections"]),128)
        self.assertEqual(len(before["biases"]),256)
        with self.assertRaises(NeuralAdmissionError): c.record(success(128))
        c.record(success(0))
        self.assertEqual(c.snapshot(),before)

    def test_failure_in_each_staged_phase_keeps_published_state(self):
        cases=[("runtime.neural_outcome.TerritoryExperienceStore.record_direct",TerritoryExperienceStore.record_direct),
               ("runtime.neural_outcome.OutcomeGradientStore.form",OutcomeGradientStore.form)]
        for target,original in cases:
            c=coordinator();c.record(success());before=c.snapshot()
            def fail_after_mutation(obj,*args,_original=original,**kwargs):
                _original(obj,*args,**kwargs)
                raise RuntimeError("injected after staged mutation")
            with patch(target,autospec=True,side_effect=fail_after_mutation):
                with self.assertRaises(RuntimeError): c.record(success(1))
            self.assertEqual(c.snapshot(),before)
        for target in ("runtime.neural_outcome.project_perceived_gradient","runtime.neural_outcome._form_biases"):
            c=coordinator();c.record(success());before=c.snapshot()
            with patch(target,side_effect=RuntimeError("injected")):
                with self.assertRaises(RuntimeError): c.record(success(1))
            self.assertEqual(c.snapshot(),before)
            c.record(success(1));self.assertEqual(len(c.snapshot()["receipts"]),2)

    def test_invalid_outcome_after_experience_staging_rolls_back(self):
        c=coordinator();before=c.snapshot();payload=success();payload["outcome_facts"]["reward_value"]="invalid"
        with self.assertRaises(NeuralAdmissionError): c.record(payload)
        self.assertEqual(c.snapshot(),before)

    def test_fixed_configuration_and_unassigned_agent(self):
        c=coordinator();before=c.snapshot()
        with self.assertRaises(AttributeError): c.run_id="other"
        with self.assertRaises(TypeError): c.parameters["npc_a"]=param(s=1)
        with self.assertRaises(FrozenInstanceError): c.parameters["npc_a"].error_sensitivity=1
        for payload in (success(agent="npc_b"),dict(success(),run_id="other"),dict(success(),parameter=asdict(param()))):
            with self.assertRaises(NeuralAdmissionError): c.record(payload)
        self.assertEqual(c.snapshot(),before)
        with self.assertRaises(NeuralAdmissionError): NeuralOutcomeCoordinator("r",[param(),param(s=1)])
        with self.assertRaises(NeuralAdmissionError): NeuralOutcomeCoordinator("r",[param(str(i)) for i in range(17)])
        self.assertEqual(len(NeuralOutcomeCoordinator("r",[param(str(i)) for i in range(16)]).parameters),16)
        for limits in ({"biases":257},{"gradients":True},{"receipts":0},{"unknown":1}):
            with self.assertRaises(NeuralAdmissionError): coordinator(capacities=limits)

    def test_no_experience_filtered_and_zero_are_distinct_synthetic(self):
        c=coordinator(1,3)
        self.assertEqual(c.build_sleep_profile("npc_a")["status"],"no_experience")
        with patch("runtime.outcome_bias._dimensions",return_value=synthetic_dimensions(1)):
            out=c.record(success())
        self.assertEqual(out["biases"],[])
        snap=c.snapshot();self.assertEqual(len(snap["projections"]),1);self.assertEqual(len(snap["receipts"]),1)
        profile=c.build_sleep_profile("npc_a")
        self.assertEqual(profile["status"],"all_relations_filtered")
        self.assertEqual(profile["profile_count"],0)
        self.assertTrue(profile["projection_summaries"][0]["dimensions"][0]["reasons"])
        self.assertEqual(c.record(success()),out)
        z=coordinator()
        with patch("runtime.outcome_bias._dimensions",return_value=synthetic_dimensions(0)): z.record(success())
        self.assertEqual(z.build_sleep_profile("npc_a")["status"],"no_nonzero_relations")

    def test_sleep_budget_32_and_33(self):
        c=coordinator()
        for i in range(8): c.record(success(i))
        self.assertEqual(len(c.sleep_materials("npc_a")["biases"]),32)
        self.assertEqual(c.build_sleep_profile("npc_a")["profile_count"],8)
        ninth=success(8);ninth["outcome_facts"]["reward_value"]="ZERO"
        # Synthetic one-nonzero event isolates the exact 32/33 boundary.
        dims=synthetic_dimensions(0);dims[0].update(direction="positive",magnitude=3,magnitude_band="STRONG")
        with patch("runtime.outcome_bias._dimensions",return_value=dims): c.record(ninth)
        self.assertEqual(len(c.sleep_materials("npc_a")["biases"]),33)
        before=c.snapshot()
        with self.assertRaisesRegex(NeuralAdmissionError,"sleep_bias_budget"): c.build_sleep_profile("npc_a")
        self.assertEqual(c.snapshot(),before)

    def test_sleep_rejects_mixed_schemas_contexts_omissions_and_tampering(self):
        c=coordinator();c.record(success());material=c.sleep_materials("npc_a")
        mutations=[lambda m:m.update(run_id="other"),lambda m:m.update(agent_id="npc_b"),
                   lambda m:m["biases"][0].update(schema="risky-food-local-bias-v1"),
                   lambda m:m["biases"][0].update(schema="nerv-shadow-bias-preview-v1"),
                   lambda m:m["biases"][0].update(magnitude=1),lambda m:m["biases"].pop(),
                   lambda m:m["biases"].append(copy.deepcopy(m["biases"][0])),
                   lambda m:m["projections"][0]["parameter"].update(error_sensitivity=1),
                   lambda m:m["projections"].append(copy.deepcopy(m["projections"][0]))]
        for mutate in mutations:
            m=copy.deepcopy(material);mutate(m)
            with self.assertRaises(NeuralAdmissionError): compile_neural_sleep_profile(m)

    def test_agents_and_runs_are_isolated(self):
        c=NeuralOutcomeCoordinator("r",[param(),param("npc_b",1,3)])
        a=c.record(success());before=c.build_sleep_profile("npc_a");b=c.record(success(agent="npc_b"))
        self.assertEqual(c.build_sleep_profile("npc_a"),before)
        self.assertTrue(all(x["agent_id"]=="npc_b" for x in c.sleep_materials("npc_b")["biases"]))
        other=NeuralOutcomeCoordinator("other",[param()]);out=other.record(success())
        self.assertNotEqual(a["biases"][0]["bias_id"],out["biases"][0]["bias_id"])
        m=c.sleep_materials("npc_a");m["biases"]+=b["biases"]
        with self.assertRaises(NeuralAdmissionError): compile_neural_sleep_profile(m)

    def test_replay_order_and_profile_grouping(self):
        a,b=coordinator(),coordinator()
        for i in (0,1,2): a.record(success(i))
        for i in (2,0,1): b.record(success(i))
        self.assertEqual(a.build_sleep_profile("npc_a"),b.build_sleep_profile("npc_a"))
        self.assertEqual(a.build_sleep_profile("npc_a")["profile_count"],3)
        self.assertEqual(len(a.sleep_materials("npc_a")["biases"]),12)

    def test_inputs_and_outputs_are_independent(self):
        c=coordinator();payload=success();before=copy.deepcopy(payload);out=c.record(payload);snap=c.snapshot()
        self.assertEqual(payload,before)
        out["projection"]["raw_record"].clear();out["biases"][0]["parameter"].clear();payload.clear()
        c.sleep_materials("npc_a")["biases"].clear()
        c.build_sleep_profile("npc_a")["projection_summaries"].clear()
        self.assertEqual(c.snapshot(),snap)

    def test_concurrent_duplicates_commit_once(self):
        c=coordinator()
        with ThreadPoolExecutor(max_workers=4) as pool:
            results=list(pool.map(lambda _:c.record(success()),range(8)))
        self.assertTrue(all(r==results[0] for r in results))
        self.assertEqual(len(c.snapshot()["receipts"]),1)
        self.assertEqual(len(c.snapshot()["biases"]),4)

    def test_old_sleep_rejects_new_schema_and_no_t1_entry(self):
        c=coordinator();c.record(success());profile=c.build_sleep_profile("npc_a")
        with self.assertRaises(LocalBiasProfileError): build_local_bias_profiles(profile)
        with self.assertRaises(LocalBiasDeepSimilarityError): build_local_bias_deep_shadow(profile,sleep_cycle="s",formation_tick=4)
        self.assertFalse(hasattr(c,"t1_cutover"));self.assertFalse(hasattr(c,"consolidate"))

    def test_existing_pipeline_and_actions_unchanged(self):
        def run(enabled):
            old=LuantiOutcomeCoordinator();neural=coordinator(1,3);canonical=GameAIFrozenComparisonSidecar();history=InteractionHistory();actions=[]
            for i in range(3):
                p=attack_payload(i);old.record(p)
                if enabled: neural.record(p);neural.build_sleep_profile("npc_a")
                obs=packet(f"o-{i}",tick=i+1);action=decide_action(obs);actions.append(action)
                history.register_decision(obs,action);canonical.capture(obs)
            sleep=old.consolidate({"agent_id":"npc_a","sleep_cycle":"n3-test","formation_tick":40})
            return actions,old.snapshot(),history.snapshot(),canonical.snapshot(),sleep
        self.assertEqual(run(False),run(True))


if __name__=="__main__": unittest.main()
