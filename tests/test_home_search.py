import unittest
from copy import deepcopy
from types import SimpleNamespace
from integrations.lightweight.world import World
from runtime.home_search import review
from runtime.landmark_exploration import initial_state

class HomeSearchTests(unittest.TestCase):
    def setup(self):
        w=World('test');w.objects=[]
        p=w.packet('npc_a',132)
        p['landmarks']['features']=[dict(ref='observed-rock',color='gray',azimuth=[-5,5],range_band='mid')]
        a=SimpleNamespace(observations={},results={},decisions={},seed=42)
        s=dict(scans=4,operations=0,outcome='not_observed',diagnostic='not_observed',candidates=[])
        return a,p,s
    def test_search_uses_observed_landmark_and_preserves_input(self):
        a,p,s=self.setup();before=deepcopy((p,s))
        action,out=review(a,p,dict(color='ochre'),s,True,None)
        self.assertEqual(action,['move',1]);self.assertEqual(out['search']['purpose'],'find-home-appearance')
        self.assertEqual(out['search']['landmark']['goal']['source_feature'],'observed-rock')
        self.assertEqual((p,s),before)
    def test_reacquisition_interrupts_search_without_resetting_budgets(self):
        a,p,s=self.setup();_,s=review(a,p,dict(color='ochre'),s,True,None)
        p['skyline']['features']=[dict(ref='new',color='ochre',azimuth=[25,35],elevation=15,range_band='far')]
        action,out=review(a,p,dict(color='ochre'),s,True,None)
        self.assertEqual(action,['turn',30]);self.assertEqual(out['search']['mode'],'homing')
        self.assertEqual(out['search']['operations'],1)
        self.assertEqual(out['search']['landmark']['selected_count'],1)
    def test_missing_body_or_home_memory_does_not_search(self):
        a,p,s=self.setup();s['outcome']=None
        for mem,linked in ((None,True),({'color':'ochre'},False)):
            action,out=review(a,p,mem,s,linked,None);self.assertEqual(action,['wait',0])
            self.assertEqual(out['search']['operations'],0)
    def test_budget_and_incomplete_are_not_home_success(self):
        a,p,s=self.setup();s['search']=dict(landmark=initial_state(),operations=32,mode='searching',purpose='find-home-appearance')
        action,out=review(a,p,dict(color='ochre'),s,True,None)
        self.assertEqual(action,['wait',0]);self.assertEqual(out['outcome'],'search_operation_budget')
        a,p,s=self.setup();p['ground']['coverage']='partial'
        action,out=review(a,p,dict(color='ochre'),s,True,None)
        self.assertEqual(action,['wait',0]);self.assertEqual(out['diagnostic'],'search_acquisition_incomplete')
