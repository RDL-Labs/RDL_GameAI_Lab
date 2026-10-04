from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest
from integrations.lightweight.energy_exploration import EnergyWorld,EnergyCampaign
from runtime.energy_connection import apply
from runtime.layered_body import step
from runtime.sleep_auto_model import body_context


class EnergyConnectionTests(unittest.TestCase):
    def test_actual_movement_cost_matches_current_load_and_resistance(self):
        w=EnergyWorld('e');w.objects=[];w.agents['npc_a'].update(x=-1.,z=0.,yaw=0.,inventory=3)
        p=w.packet('npc_a',8);b=p['locomotor'];before=deepcopy(w.bodies['npc_a'])
        c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],
               capture_us=p['capture_us'],expires_us=p['capture_us']+1500000,pose_ref=p['pose_ref'],
               body_revision=p['body_revision'],kind='move',amount=.5,reason='test',target_ref='')
        r=w.execute(c,p);self.assertEqual(r['status'],'moved')
        resistance=next(s['resistance'] for s in b['energy']['samples'] if s['angle']==0)
        after,_=step(before,'walk',load=3,resistance=resistance)
        self.assertEqual(w.bodies['npc_a'],after)
        saved=deepcopy(w.bodies);self.assertEqual(w.execute(c,p),r);self.assertEqual(saved,w.bodies)

    def test_energy_ranks_only_existing_candidates(self):
        w=EnergyWorld('e');w.objects=[];p=w.packet('npc_a',8)
        for s in p['locomotor']['energy']['samples']:s.update(clear=True,resistance=5. if s['angle']==0 else 1.)
        c=[dict(model='f/front',action=['move',.5],question='view_changed',score=2.,last_selected=0),
           dict(model='f/right',action=['turn',90],question='rotation_then_step',score=2.,last_selected=0)]
        trace=apply(p,c);self.assertTrue(trace['changed']);self.assertEqual(trace['selected'],'f/right')
        self.assertEqual({x['model'] for x in c},{'f/front','f/right'})

    def test_unknown_cannot_be_restored_by_score(self):
        w=EnergyWorld('e');p=w.packet('npc_a',8)
        for s in p['locomotor']['energy']['samples']:s['clear']=None
        c=[dict(model='f/front',action=['move',.5],question='view_changed',score=100.,last_selected=0)]
        apply(p,c);self.assertEqual(c[0]['action'],['wait',0])
        self.assertEqual(c[0]['model'],'energy/no_feasible_move')
        self.assertFalse(c[0]['record_trial'])

    def test_fallback_wait_does_not_credit_movement_on_next_observation(self):
        from tests.test_continuous_selection import context,tick
        from runtime.continuous_selection import review
        for clear in (None,False):
            with self.subTest(clear=clear):
                a,p,d,r=context('exploration');a.energy_enabled=True
                p['locomotor']=EnergyWorld('e').packet('npc_a',8)['locomotor']
                for sample in p['locomotor']['energy']['samples']:sample['clear']=clear
                d.update(action=['move',.5],reason='explore')
                first=review(a,p,d)
                # Seed a residual below the reselection threshold, from an older trial.
                first['continuous_selection']['nodes']['food/baseline']['H']=1
                nodes=deepcopy(first['continuous_selection']['nodes'])
                self.assertEqual(first['action'],['wait',0])
                self.assertNotIn('trial',first['continuous_selection'])
                p=tick(a,p,first,r)
                second=review(a,p,d)
                self.assertEqual(second['continuous_selection']['nodes'],nodes)
                self.assertEqual(second['continuous_selection']['events'],[])
                # A later feasible move still receives its own ordinary trial.
                for sample in p['locomotor']['energy']['samples']:sample['clear']=True
                resumed=review(a,p,d)
                self.assertEqual(resumed['action'],['move',.5])
                self.assertEqual(resumed['continuous_selection']['trial']['model'],'food/baseline')

    def test_sleep_context_separates_load_resistance_and_legacy(self):
        w=EnergyWorld('e');b=w.packet('npc_a',8)['locomotor'];old=body_context(b)
        q=deepcopy(b);q['energy']['load']+=1;self.assertNotEqual(old,body_context(q))
        q=deepcopy(b);q['energy']['samples'][0]['resistance']=9.;self.assertNotEqual(old,body_context(q))
        q=deepcopy(b);del q['energy'];self.assertNotEqual(old,body_context(q))

    def test_saved_world_results_and_sleep_sources(self):
        root=Path('tests/fixtures/energy_connection');report=json.loads((root/'comparison.json').read_text(encoding='utf8'))
        for name,entry in report.items():
            with gzip.open(root/(name+'.jsonl.gz'),'rt',encoding='utf8') as f:rows=[json.loads(x) for x in f]
            sources={r['packet']['observation_id']:r['packet'] for r in rows if r['type']=='decision'}
            for a in entry['summary']['agents'].values():
                for cycle in a['sleep']['completed']+[a['sleep']['cycle']]:
                    self.assertIn(cycle['status'],('completed','interrupted','pending'))
                    if cycle['relation_review'] is None:continue
                    for r in cycle['relation_review']['records']:
                        self.assertEqual(r['body_observation'],sources[r['source_observation_id']]['locomotor'])
            self.assertTrue(entry['audit']['body_continuity']);self.assertEqual(entry['audit']['duplicate_effects'],0)
            self.assertEqual(entry['energy_fields']==0,name.endswith('shadow'))
