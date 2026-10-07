from copy import deepcopy
from types import SimpleNamespace
import unittest
from runtime.body_method_field import apply


class BodyMethodFieldTests(unittest.TestCase):
    def evaluate(self,reserve,strain,phase='exploration',gate='method_reselection'):
        agent=SimpleNamespace(agent_id='a',learning={})
        packet=dict(capture_us=0,observation_id='o',social=dict(body=dict(reserve=reserve,strain=strain)))
        selection=dict(gate=gate,candidates=[
            dict(model='food/wait',action=['wait',0],score=1.2,last_selected=0),
            dict(model='food/step_0',action=['move',.5],score=1.,last_selected=0)])
        trace=apply(agent,packet,selection,phase)
        self.assertEqual(agent.learning,{})
        return trace,selection

    def test_hunger_changes_existing_choice(self):
        trace,selection=self.evaluate(20,0)
        self.assertEqual(trace['baseline'],'food/wait')
        self.assertEqual(trace['selected'],'food/step_0')
        self.assertTrue(trace['changed'])
        self.assertEqual(len(selection['candidates']),2)

    def test_fatigue_rest_and_return(self):
        self.assertEqual(self.evaluate(90,.9,'return')[0]['selected'],'food/wait')
        self.assertGreater(self.evaluate(90,.9)[0]['contributions'][0]['delta'],0)

    def test_protected_and_infeasible_stay_protected(self):
        for phase in ('safety','night','orientation'):
            self.assertFalse(self.evaluate(0,0,phase)[0]['applied'])
        self.assertFalse(self.evaluate(0,0,gate='current_feasible_proposal')[0]['applied'])
        agent=SimpleNamespace(agent_id='a',learning={})
        p=dict(capture_us=0,observation_id='o',social=dict(body=dict(reserve=0,strain=0)))
        s=dict(gate='method_reselection',candidates=[dict(model='energy/no_feasible_move',
            action=['wait',0],score=0,last_selected=0,record_trial=False)])
        before=deepcopy(s);self.assertFalse(apply(agent,p,s,'exploration')['applied'])
        self.assertEqual(s,before)


if __name__=='__main__':unittest.main()
