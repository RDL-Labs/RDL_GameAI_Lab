import unittest
from copy import deepcopy
from runtime.aid_relations import AidRelations
from integrations.lightweight.aid_relation_experiment import experiment,RelationWorld


class AidRelationTests(unittest.TestCase):
    def test_same_absence_different_hidden_cause(self):
        results=experiment();yes=results['help'];no=results['decline'];unheard=results['unheard']
        self.assertEqual(yes['next_expected_helper'],'npc_b')
        self.assertEqual(no['next_expected_helper'],'npc_c')
        self.assertEqual(unheard['next_expected_helper'],'npc_c')
        self.assertEqual(no['own_evidence'],unheard['own_evidence'])
        self.assertTrue(no['helper_records'][0]['observation']['heard'])
        self.assertFalse(unheard['helper_records'][0]['observation']['heard'])
        for result in results.values():
            self.assertEqual(result['own_evidence']['intent'],'unknown')
            self.assertEqual(result['reverse_expectation'],.5)
        self.assertEqual(no['expectations']['npc_b'],1/3)
        self.assertEqual(no['later_help']['expectations']['npc_b'],.5)
        self.assertEqual(yes['expectations']['npc_b'],2/3)

    def test_deadline_replay_and_no_invisible_blame(self):
        a=AidRelations('npc_a',('npc_a','npc_b','npc_c'))
        with self.assertRaises(ValueError):a.begin('e','npc_b',dict(near=[]),0)
        a.begin('e','npc_b',dict(near=[dict(ref='npc_b')]),0)
        with self.assertRaises(ValueError):a.finish('e',dict(received_aid=[]),2)
        first=a.finish('e',dict(received_aid=[]),3)
        self.assertEqual(a.finish('e',dict(received_aid=[]),4),first)
        self.assertEqual(len(a.evidence),1)
        self.assertEqual(a.expectation('npc_c'),.5)
        first['outcome']='edited';self.assertEqual(a.evidence['e']['outcome'],'no_aid_observed')

    def test_recipient_receipt_not_duplicated(self):
        w=RelationWorld();w.objects=[]
        for a in w.agents.values():a.update(x=0.,z=0.,inventory=1)
        w.act_rescue('npc_a','c','call')
        w.act_rescue('npc_b','f','feed','npc_a');before=deepcopy(w.received)
        w.act_rescue('npc_b','f','feed','npc_a')
        self.assertEqual(before,w.received);self.assertEqual(len(w.received['npc_a']),1)

    def test_unrelated_or_late_aid_is_not_target_success(self):
        a=AidRelations('npc_a',('npc_a','npc_b','npc_c'))
        a.begin('e','npc_b',dict(near=[dict(ref='npc_b')]),0)
        result=a.finish('e',dict(received_aid=[dict(giver='npc_c',time=1),dict(giver='npc_b',time=3)]),3)
        self.assertEqual(result['outcome'],'no_aid_observed')
