from copy import deepcopy
from types import SimpleNamespace
from unittest.mock import patch
import unittest
from runtime.harvest_sleep import accept_rest_result


class SleepReceiptBoundaryTests(unittest.TestCase):
    def fixture(self):
        p=dict(observation_id='night-last',capture_us=17278000000,pose_ref='pose',body_revision=4)
        c=dict(operation_id='op:night-last',kind='wait')
        r=dict(executed_us=17279000000,status='waited',after_pose_ref='pose',after_revision=4)
        cycle=dict(day=0,status='pending',rest_us=2879000000,records=[],
            relation_materials=dict(records=[],window={}))
        a=SimpleNamespace(sleep_receipt_intake=True,results={c['operation_id']:r},
            decisions={p['observation_id']:dict(day_cycle=dict(phase='night'))},
            learning=dict(sleep=dict(cycle=cycle,completed=[])),model=None,
            sleep_rest_credit=lambda p,r,current:r['executed_us']-p['capture_us'])
        return a,p,c,r

    def test_last_second_completes_without_next_observation(self):
        a,p,c,r=self.fixture();before=deepcopy(p)
        with patch('runtime.harvest_sleep.DAY_US',17280000000),patch('runtime.harvest_sleep.REST_US',2880000000):
            self.assertTrue(accept_rest_result(a,p,c,r))
            self.assertEqual(a.learning['sleep']['cycle']['status'],'completed')
            self.assertEqual(a.learning['sleep']['cycle']['rest_us'],2880000000)
            self.assertFalse(accept_rest_result(a,p,c,r))
        self.assertEqual(p,before)

    def test_rejected_missing_and_duplicate_pending_results(self):
        a,p,c,r=self.fixture()
        with patch('runtime.harvest_sleep.DAY_US',17280000000),patch('runtime.harvest_sleep.REST_US',3000000000):
            accept_rest_result(a,p,c,r);state=deepcopy(a.learning)
            self.assertFalse(accept_rest_result(a,p,c,r));self.assertEqual(a.learning,state)
            with self.assertRaises(ValueError):accept_rest_result(a,p,c,dict(r,status='blocked'))

    def test_failed_wait_does_not_complete(self):
        a,p,c,r=self.fixture();r['status']='blocked'
        with patch('runtime.harvest_sleep.DAY_US',17280000000):
            accept_rest_result(a,p,c,r)
        self.assertEqual(a.learning['sleep']['cycle']['rest_us'],0)


if __name__=='__main__':unittest.main()
