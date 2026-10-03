from copy import deepcopy
from types import SimpleNamespace
import unittest
from runtime.sleep_auto_model import adopt, apply


def record(i, outcome='blocked', action='move', amount=1):
    return dict(record_id=str(i), agent_id='a', tick=i, action=action, amount=amount,
        food_coverage='complete', hazard_coverage='complete', food_seen=False,
        hazard_seen=False, outcome=outcome)


class SleepAutoTests(unittest.TestCase):
    def test_failure_is_adopted_and_changes_choice(self):
        m = adopt(None, dict(records=[record(1)]), 'r', 'a', 10)
        self.assertEqual(m['cells'][0]['execution_rate'], 0)
        agent = SimpleNamespace(_prospective=({'sleep_auto_model':m}, None))
        p = dict(run_id='r', agent_id='a', capture_us=20,
            food=dict(coverage='complete',visible=[]), hazard=dict(coverage='complete',features=[]))
        cs = [dict(model='move',action=['move',1],score=2),dict(model='turn',action=['turn',90],score=1.5)]
        self.assertEqual(max(cs,key=lambda c:c['score'])['model'],'move')
        before=deepcopy(m);trace=apply(agent,p,cs)
        self.assertEqual(max(cs,key=lambda c:c['score'])['model'],'turn')
        self.assertEqual(trace['status'],'applied');self.assertEqual(m,before)
        p['food']['coverage']='partial'
        self.assertEqual(apply(agent,p,cs)['status'],'context_unavailable')

    def test_repeated_sleep_not_extra_support_and_counterexample_retained(self):
        review=dict(records=[record(1),record(2,'moved')])
        m=adopt(None,review,'r','a',10)
        again=adopt(m,review,'r','a',20)
        self.assertEqual(m['model_ref'],again['model_ref'])
        self.assertEqual(again['cells'][0]['support'],2)
        self.assertEqual(again['cells'][0]['execution_rate'],.5)
        self.assertEqual(again['cells'][0]['negative'],1)
        with self.assertRaises(ValueError):adopt(m,dict(records=[record(1,'moved')]),'r','a',30)

    def test_missing_foreign_and_future(self):
        r=record(1);r['food_coverage']='partial'
        self.assertEqual(adopt(None,dict(records=[r]),'r','a',10)['cells'],[])
        for r in (dict(record(1),agent_id='b'),record(11)):
            with self.assertRaises(ValueError):adopt(None,dict(records=[r]),'r','a',10)

    def test_wait_success_can_become_bias_without_goal_success(self):
        m=adopt(None,dict(records=[record(1,'waited','wait',0)]),'r','a',10)
        self.assertEqual(m['cells'][0]['execution_rate'],1)
        self.assertEqual(m['cells'][0]['action'],['wait',0])

    def test_saved_world_automatic_model_and_adverse_result(self):
        import json
        from pathlib import Path
        reports=json.loads(Path('tests/fixtures/lightweight_sleep_auto_comparison.json').read_text())
        self.assertEqual(reports['False']['pickups'],48)
        self.assertEqual(reports['True']['pickups'],45)
        for aid,a in reports['True']['agents'].items():
            model=a['sleep_auto_model']
            self.assertEqual(model['binding'][1],aid)
            self.assertTrue(model['cells'])
            ids=[r['record_id'] for r in model['records']]
            self.assertEqual(len(ids),len(set(ids)))
        self.assertEqual(sum(a['unloaded'] for a in reports['True']['agents'].values()),27)


if __name__=='__main__':unittest.main()
