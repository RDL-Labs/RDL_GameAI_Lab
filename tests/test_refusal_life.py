from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest
from integrations.lightweight.social_life import SocialWorld,SocialCampaign
from integrations.lightweight.timed_harvest import run


class RefusalLifeTests(unittest.TestCase):
    def test_saved_three_seed_comparison_and_first_divergence(self):
        root=Path('tests/fixtures/refusal_life');report=json.loads((root/'comparison.json').read_text(encoding='utf8'))
        for seed in (20261004,20261005,20261006):
            for mode in ('shadow','enabled'):
                r=report[f'{seed}-{mode}'];self.assertTrue(r['audit']['conserved']);self.assertFalse(r['audit']['body_overlap'])
                for cycles in r['audit']['sleep_cycles'].values():self.assertEqual(cycles,['completed']*3)
            a=report[f'{seed}-shadow'];b=report[f'{seed}-enabled']
            self.assertEqual(a['audit']['actions'],b['audit']['actions'])
        rows=[]
        for mode in ('shadow','enabled'):
            with gzip.open(root/f'20261005-{mode}.jsonl.gz','rt',encoding='utf8') as f:
                row=next(r for line in f if (r:=json.loads(line))['type']=='decision'
                         and r['packet']['agent_id']=='npc_a' and r['packet']['capture_us']==5000000)
            rows.append(row)
        self.assertEqual(rows[0]['packet'],rows[1]['packet'])
        self.assertEqual(rows[0]['refusal_choice']['draw'],rows[1]['refusal_choice']['draw'])
        self.assertEqual(rows[0]['refusal_choice']['selected'],'request')
        self.assertEqual(rows[1]['refusal_choice']['selected'],'wait')
        self.assertNotEqual(rows[1]['command']['kind'],'social')
        self.assertIsNone(rows[1]['social_relations']['pending'])

    def test_runtime_retry_freezes_choice_and_pending(self):
        w=SocialWorld('retry');w.objects=[]
        for a in w.agents.values():a.update(x=0.,z=5.8,inventory=2)
        w.agents['npc_a']['inventory']=0;w.bodies['npc_a']['reserve']=20
        loop=SocialCampaign('retry',1);a=loop.agents['npc_a'];a.refusal_field_mode='enabled'
        loop.configure(dict(w.context('npc_a'),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',
                            teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        p=w.packet('npc_a',8);first=loop.observe(p);state=deepcopy(a.learning)
        trace=deepcopy(a.decisions[p['observation_id']].get('refusal_choice'))
        self.assertIsNotNone(trace)
        self.assertEqual(loop.observe(deepcopy(p))['command'],first['command'])
        self.assertEqual(state,a.learning)
        self.assertEqual(trace,a.decisions[p['observation_id']]['refusal_choice'])

    def test_dependencies(self):
        with self.assertRaises(ValueError):run('unused.jsonl',refusal_field_mode='enabled')
