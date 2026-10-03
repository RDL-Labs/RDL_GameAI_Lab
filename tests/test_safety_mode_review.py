import unittest
from copy import deepcopy
from tests.test_moving_hazard_safety import packet
from runtime.moving_hazard_safety import KEYS
from runtime.safety_mode_review import evaluate


def advance(p,r,coverage='partial',visible=False):
    p=deepcopy(p);r=deepcopy(r);p['capture_us']+=1000000;p['observation_id']+='n'
    p['hazard']['source']={k:p[k] for k in KEYS};p['hazard']['coverage']=coverage
    p['hazard']['features']=([dict(appearance='violet_warning',azimuth=[0,15],range_band='near')] if visible else [])
    r.update(status='waited',executed_us=p['capture_us']-1,yaw=0)
    return p,r


class ModeReviewTests(unittest.TestCase):
    def sequence(self,coverage,mode='enabled'):
        _,p,_,_,r=packet();s=evaluate(p,None,r,mode)
        for i in range(8):
            p,r=advance(p,r,coverage);s=evaluate(p,s,r,mode)
            if not s['override']:return i+1,s,p,r
        return 8,s,p,r

    def test_complete_and_partial_have_distinct_evidence_and_timing(self):
        n,s,_,_=self.sequence('complete');self.assertEqual(n,4)
        self.assertEqual(s['reason'],'provisional_mode_release')
        n,s,_,_=self.sequence('partial');self.assertEqual(n,8)
        self.assertEqual(s['mode_model']['events'][-1]['reason'],'basis_unrenewed_under_partial_observation')
        self.assertFalse(s['mode_model']['events'][-1]['safety_proven'])

    def test_shadow_does_not_release(self):
        _,s,_,_=self.sequence('partial','shadow')
        self.assertTrue(s['override']);self.assertTrue(s['mode_model']['eligible']);self.assertFalse(s['mode_model']['applied'])

    def test_observed_warning_renews_even_with_partial_coverage(self):
        _,p,_,_,r=packet();s=evaluate(p,None,r)
        for _ in range(24):
            p,r=advance(p,r,visible=True);s=evaluate(p,s,r)
            self.assertEqual(s['mode_model']['H'],0);self.assertTrue(s['override'])

    def test_reentry_after_provisional_release(self):
        _,s,p,r=self.sequence('partial');generation=s['generation']
        p,r=advance(p,r,visible=True);s=evaluate(p,s,r)
        self.assertTrue(s['override']);self.assertEqual(s['generation'],generation+1);self.assertEqual(s['mode_model']['H'],0)

    def test_replay_does_not_accumulate(self):
        _,s,p,r=self.sequence('partial','shadow');before=deepcopy(s)
        self.assertEqual(evaluate(p,s,r,'shadow'),s);self.assertEqual(s,before)
        p['hazard']['coverage']='complete'
        with self.assertRaises(ValueError):evaluate(p,s,r,'shadow')

    def test_unlinked_does_not_accumulate(self):
        _,p,_,_,r=packet();s=evaluate(p,None,r)
        for _ in range(20):
            p,r=advance(p,r);r['after_pose_ref']='bad';s=evaluate(p,s,r)
        self.assertEqual(s['mode_model']['H'],0);self.assertTrue(s['override'])

    def test_one_review_per_interval_no_catchup(self):
        _,p,_,_,r=packet();s=evaluate(p,None,r);p,r=advance(p,r)
        p['capture_us']+=20000000;p['hazard']['source']['capture_us']=p['capture_us']
        s=evaluate(p,s,r);self.assertEqual(s['mode_model']['H'],1)
        self.assertEqual(s['mode'],'safety_unresolved')

    def test_binding(self):
        _,p,_,_,r=packet();s=evaluate(p,None,r);p,r=advance(p,r);p['agent_id']='another'
        with self.assertRaises(ValueError):evaluate(p,s,r)


if __name__=='__main__':unittest.main()
