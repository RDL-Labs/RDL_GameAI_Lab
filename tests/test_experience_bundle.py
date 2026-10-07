import unittest
from copy import deepcopy
from types import SimpleNamespace
from runtime.experience_bundle import form,apply
from runtime.hunger_review import update


def packet(t,ident):
    return dict(run_id='r',agent_id='a',capture_us=t,observation_id=ident,
        social=dict(food_band='none',body=dict(reserve=60,strain=.1)),
        food=dict(coverage='complete',visible=[]),hazard=dict(coverage='complete',features=[]))


class BundleTests(unittest.TestCase):
    def setup_case(self):
        p=packet(0,'old');q=packet(10000000,'now')
        a=SimpleNamespace(agent_id='a',learning={},observations={'old':p},
            commands={'old':dict(operation_id='op',kind='wait')},
            results={'op':dict(operation_id='op',executed_us=1000000,status='waited')},
            decisions={'old':dict(day_cycle=dict(phase='exploration'))},experience_bundle_mode='enabled')
        h=update(None,'a',0,60,'first');h=update(h,'a',5000000,60,'middle');h=update(h,'a',10000000,60,'now')
        return a,q,h

    def test_formation_sources_replay_and_no_duplicate_support(self):
        a,p,h=self.setup_case();s=form(a,p,h)
        self.assertEqual(len(s['bundles']),1);self.assertEqual(s['used'],['op'])
        self.assertEqual(a.learning,{})
        a.learning['experience_bundles']=s
        self.assertEqual(form(a,p,h),s)
        h=update(h,'a',15000000,60,'later')
        self.assertEqual(len(form(a,packet(15000000,'later'),h)['bundles']),1)

    def test_later_reactivation_changes_choice_but_not_shadow_or_protected(self):
        a,p,h=self.setup_case();a.learning['experience_bundles']=form(a,p,h)
        def selection():return dict(gate='method_reselection',candidates=[
            dict(model='food/wait',score=1.2,action=['wait',0],last_selected=0),
            dict(model='food/move',score=1,action=['move',.5],last_selected=0)])
        q=packet(11000000,'next');s=selection()
        self.assertTrue(apply(a,q,s,'exploration')['changed'])
        a.experience_bundle_mode='shadow';s=selection();before=deepcopy(s)
        self.assertFalse(apply(a,q,s,'exploration')['changed']);self.assertEqual(s,before)
        self.assertEqual(apply(a,q,s,'safety')['status'],'protected')
        self.assertEqual(apply(a,p,selection(),'exploration')['status'],'no_match')

    def test_cross_agent_rejected(self):
        a,p,h=self.setup_case();a.observations['old']['agent_id']='b'
        with self.assertRaises(ValueError):form(a,p,h)

    def test_capacity_is_explicit_and_models_preserved(self):
        a,p,h=self.setup_case();s=form(a,p,h)
        s['bundles']=s['bundles']*32
        a.learning['experience_bundles']=s
        h=update(h,'a',15000000,60,'later')
        result=form(a,packet(15000000,'later'),h)
        self.assertEqual(result['formation_status'],'capacity_reached')
        self.assertEqual(result['bundles'],s['bundles'])


if __name__=='__main__':unittest.main()
