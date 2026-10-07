import unittest
from copy import deepcopy
from types import SimpleNamespace
from runtime.bundle_sleep import review
from runtime.experience_bundle import context
from tests.test_experience_bundle import packet


class BundleSleepTests(unittest.TestCase):
    def test_usage_requires_executed_final_choice_and_counts_once(self):
        p=packet(100,'now')
        a=SimpleNamespace(observations={'old':dict(observation_id='old')},
            decisions={'old':dict(continuous_selection=dict(selected='m',
                candidates=[dict(model='m',action=['move',1])],experience_bundle=dict(
                    changed=True,matched_refs=['b'],contributions=[dict(model_refs=['b'])])))},
            commands={'old':dict(operation_id='op',kind='move',amount=1)},
            results={'op':dict(status='blocked',executed_us=90)})
        s=dict(binding=['r','a'],bundles=[],used=[])
        r=review(s,a,p,None,50)
        self.assertEqual(r['usage']['b']['uses'],1)  # Execution, not success.
        self.assertEqual(review(r,a,p,None,50),r)
        a.commands['old']['kind']='wait'
        r=review(s,a,p,None,50)
        self.assertEqual(r['usage']['b']['uses'],0)
        self.assertEqual(r['usage']['b']['opportunities'],1)

    def test_completed_only_dormancy_replay_and_wake(self):
        p=packet(100,'now');a=SimpleNamespace(observations={},decisions={},commands={},results={})
        b=dict(model_ref='b',formed_us=0,sources=[dict(context=context(p),phase='exploration')])
        s=dict(binding=['r','a'],bundles=[b],used=['op'])
        cycle=dict(status='interrupted',day=0,source='sleep')
        s=review(s,a,p,cycle,50)
        self.assertEqual(s['sleep_cycles'],[])
        for day in range(3):
            cycle=dict(status='completed',day=day,source='sleep')
            s=review(s,a,p,cycle,50)
            self.assertEqual(review(s,a,p,cycle,50),s)
        self.assertEqual(s['bundles'],[]);self.assertEqual(len(s['dormant']),1)
        self.assertEqual(s['sleep_reviews'][-1]['decisions'][0]['reason'],'no_opportunity')
        awake=review(s,a,p,cycle,50,'exploration')
        self.assertEqual(awake['woken'],['b']);self.assertEqual(awake['used'],['op'])

    def test_matched_not_used_is_distinct_and_own_binding(self):
        p=packet(100,'now');a=SimpleNamespace(observations={},decisions={},commands={},results={})
        s=dict(binding=['r','a'],bundles=[dict(model_ref='b',formed_us=0,sources=[])],used=[],
               usage={'b':dict(opportunities=1,uses=0,idle_sleeps=1)})
        result=review(s,a,p,dict(status='completed',day=0,source='s'),50)
        self.assertEqual(result['sleep_reviews'][0]['decisions'][0]['reason'],'matched_without_executed_change')
        self.assertEqual(len(result['dormant']),1)
        p['agent_id']='b'
        with self.assertRaises(ValueError):review(s,a,p,None,50)

    def test_used_retained_and_new_material_not_retrospectively_aged(self):
        a=SimpleNamespace(observations={},decisions={},commands={},results={});p=packet(100,'now')
        s=dict(binding=['r','a'],bundles=[dict(model_ref='b',formed_us=0),dict(model_ref='new',formed_us=90)],used=[],
            usage={'b':dict(opportunities=1,uses=1,idle_sleeps=5)})
        r=review(s,a,p,dict(status='completed',day=0,source='s'),50)
        self.assertEqual(len(r['bundles']),2);self.assertEqual(r['usage']['b']['idle_sleeps'],0)
        self.assertEqual(len(r['sleep_reviews'][0]['decisions']),1)


if __name__=='__main__':unittest.main()
