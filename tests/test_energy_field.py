from copy import deepcopy
import json
from pathlib import Path
import unittest
from runtime.energy_field import evaluate
from runtime.layered_body import initial,step
from integrations.lightweight.energy_field_comparison import EnergyWorld,experiment


class EnergyFieldTests(unittest.TestCase):
    def test_choice_and_actual_cost(self):
        r=experiment()
        self.assertEqual(r['easy']['field']['action'],'walk')
        self.assertEqual(r['resistive']['field']['action'],'detour')
        for k in ('easy','resistive','low_reserve'):
            f=r[k]['field'];receipt=r[k]['result']
            row=next(x for x in f['rows'] if x['ref']==f['selected'])
            for key,delta in row['expected_delta'].items():
                self.assertAlmostEqual(receipt['after']['body'][key]-receipt['before']['body'][key],delta)
        self.assertEqual(r['low_reserve']['field']['rows'][0]['status'],'body_limited')

    def test_unknown_and_blocked_not_cheap(self):
        w=EnergyWorld();s=w.samples('npc_a');before=deepcopy(s)
        s[0]['clear']=None;s[1]['clear']=False
        f=evaluate(initial(),0,s)
        self.assertIsNone(f['selected']);self.assertEqual(f['action'],'rest')
        self.assertEqual([x['cost'] for x in f['rows']],[None,None])
        self.assertEqual(before[0]['clear'],True)

    def test_other_agent_changes_retrieval_not_total(self):
        r=experiment()['interaction'];records=r['records']
        self.assertEqual(records[7]['status'],'picked_up')
        self.assertEqual(records[8]['status'],'unavailable')
        self.assertGreaterEqual(records[7]['start_us'],records[6]['end_us'])
        self.assertGreaterEqual(records[8]['start_us'],records[7]['end_us'])
        self.assertEqual(r['audit'],dict(carried=6,ground=0,total_weight=6.))
        self.assertEqual(len(records[-2]['before']['weights']),5)
        self.assertEqual(len(records[-1]['before']['weights']),1)

    def test_replay_does_not_spend_twice(self):
        w=EnergyWorld(5.);f=w.decide('npc_a')
        r=w.execute_cargo('npc_a','go',f['action']);state=deepcopy(w.states)
        self.assertEqual(w.execute_cargo('npc_a','go',f['action']),r);self.assertEqual(w.states,state)

    def test_budget_resistance_and_purity(self):
        w=EnergyWorld();s=w.samples('npc_a');body=initial();before=deepcopy(body)
        evaluate(body,2,s);self.assertEqual(body,before)
        with self.assertRaises(ValueError):evaluate(body,2,s*3)
        for x in (0,-1,float('nan'),11,True):
            with self.assertRaises(ValueError):step(body,'walk',resistance=x)

    def test_saved(self):
        self.assertEqual(json.loads(Path('tests/fixtures/energy_field.json').read_text(encoding='utf8')),experiment())
