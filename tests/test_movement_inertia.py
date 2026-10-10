import unittest
from tests.test_continuous_selection import context, tick
from runtime.continuous_selection import review


class InertiaTests(unittest.TestCase):
    def ready(self):
        a,p,d,r=context('exploration');a.movement_inertia=True
        p['hazard'].update(features=[],coverage='complete');p['food']['visible']=[]
        for x in p['movement_surface']['ground']['samples']:x.update(status='sampled',height_delta=0)
        p['movement_surface']['ground']['output_limited']=False
        d.update(action=['move',1],reason='test_move');r.update(forward=1,right=0)
        out=review(a,p,d);p=tick(a,p,out,r)
        d.update(action=['turn',90],reason='changed_proposal')
        return a,p,d,r

    def test_retains_confirmed_move(self):
        a,p,d,r=self.ready();out=review(a,p,d)
        self.assertEqual(out['action'],['move',1])
        self.assertEqual(out['continuous_selection']['gate'],'inertial_current_step')
        self.assertEqual(len(out['continuous_selection']['candidates']),1)

    def test_interrupts(self):
        for condition in ('hazard','surface','phase','pickup','blocked','threshold'):
            with self.subTest(condition=condition):
                a,p,d,r=self.ready()
                if condition=='hazard':p['hazard']['coverage']='partial'
                if condition=='surface':p['movement_surface']['ground']['output_limited']=True
                if condition=='phase':d['day_cycle']['phase']='night'
                if condition=='pickup':d['action']=['pickup',0]
                if condition=='blocked':next(iter(a.results.values()))['status']='blocked'
                if condition=='threshold':next(iter(a.decisions.values()))['continuous_selection']['inertia']['H']=4
                out=review(a,p,d)
                self.assertFalse(out['continuous_selection']['inertia']['continued'])

    def test_body_wait_not_movement_success(self):
        a,p,d,r=self.ready();a.body_candidate=lambda p,action:['wait',0]
        out=review(a,p,d)
        self.assertNotIn('trial',out['continuous_selection'])
        self.assertEqual(out['continuous_selection']['inertia']['interrupt'],'body_limited')


if __name__=='__main__':unittest.main()
