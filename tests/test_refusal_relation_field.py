import unittest
from copy import deepcopy
from integrations.lightweight.refusal_field_comparison import learn,experiment,world
from runtime.refusal_relation_field import compile_field,choose


class RefusalFieldTests(unittest.TestCase):
    def test_actual_refusals_retain_H_weight(self):
        field,training=learn()
        self.assertEqual(field['relations']['npc_b']['H_samples'],[1,2])
        self.assertEqual(field['relations']['npc_b']['weight'],1.2)
        self.assertEqual(len(field['relations']['npc_b']['sources']),2)
        self.assertEqual(compile_field(training['records'],training['pressure'],'npc_a'),field)

    def test_matched_choice_probabilities_and_world_effects(self):
        r=experiment()['cases']
        for question,action in [('request','request'),('response','give')]:
            self.assertLess(r[question+'_trace']['selected'][action],r[question+'_control']['selected'][action])
            for baseline,enabled in zip(r[question+'_control']['runs'],r[question+'_trace']['runs']):
                self.assertEqual(baseline['observation'],enabled['observation'])
                self.assertEqual(baseline['trace']['draw'],enabled['trace']['draw'])
        self.assertGreater(r['affiliation']['selected']['give'],r['response_trace']['selected']['give'])
        self.assertEqual(r['no_response']['selected'],r['response_control']['selected'])
        self.assertEqual(r['no_food']['selected']['give'],0)

    def test_current_need_and_unrelated_partner(self):
        field,_=learn();w=world();w.agents['npc_a']['inventory']=2
        w.communicate('npc_b','q','request','npc_a');o=w.observe_communication('npc_a')
        _,well=choose(field,o,'npc_b','respond',0)
        hungry=deepcopy(o);hungry['body']['reserve']=0
        _,low=choose(field,hungry,'npc_b','respond',0)
        self.assertLess(low['candidates'][1]['probability'],well['candidates'][1]['probability'])
        w.communicate('npc_c','q','request','npc_a')
        _,other=choose(field,w.observe_communication('npc_a'),'npc_c','respond',0)
        self.assertEqual(other['weight'],0)

    def test_missing_or_cross_agent_evidence_rejected(self):
        field,training=learn()
        with self.assertRaises(ValueError):compile_field(training['records'],training['pressure'],'npc_c')
        pressure=deepcopy(training['pressure'])
        pressure['methods']['npc_b']['records']['npc_a:q0']['E']=None
        with self.assertRaises(ValueError):compile_field(training['records'],pressure,'npc_a')
        w=world()
        with self.assertRaises(ValueError):choose(field,w.observe_communication('npc_c'),'npc_b','request_again',0)
