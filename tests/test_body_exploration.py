from copy import deepcopy
import json
from pathlib import Path
import unittest

from integrations.lightweight.body_exploration import BodyCampaign, ExplorationBodyWorld, experiment, run_case


class BodyExplorationTests(unittest.TestCase):
    def setup_loop(self):
        w=ExplorationBodyWorld('body-test'); w.objects=[];w.resources=[dict(x=0.,z=1.8,stock=1)]
        w.agents['npc_a'].update(x=0.,z=0.,yaw=0.)
        l=BodyCampaign(w.run_id,1)
        l.configure(dict(w.context('npc_a'),schema=l.schema,clock_id='world-sim-v1',selection_profile='steady',
                         teaching=dict(statement_id='t',source='god_statue',sample_observation='s',
                                       appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        return w,l

    def test_runtime_connected_comparison(self):
        e=experiment()
        self.assertEqual([e[k]['acquired'] for k in ('disabled','enabled','recover','too_high')],[0,1,1,0])
        self.assertEqual([r['command']['kind'] for r in e['recover']['records']][:4],['wait','wait','climb','pickup'])
        for case in e.values():
            self.assertEqual(case['runtime_results'],len(case['records']))
            self.assertTrue(all(r['receipt']['accepted'] for r in case['records']))
        # Partial ground must not be silently converted to complete learning evidence.
        self.assertEqual(e['enabled']['learning_records'],0)

    def test_walk_reports_half_unit_and_invalid_distance_rejected(self):
        w,l=self.setup_loop();p=w.packet('npc_a',8);c=l.observe(p)['command']
        self.assertEqual(c['kind'],'move');self.assertEqual(c['amount'],.5)
        r=w.execute(c,p);self.assertEqual(r['forward'],.5)
        with self.assertRaises(ValueError):l.result(dict(r,forward=1))
        self.assertEqual(len(l.agents['npc_a'].results),0)
        self.assertTrue(l.result(r)['accepted'])
        self.assertEqual(run_case(height=None)['acquired'],1)

    def test_replay_once_and_individual_isolation(self):
        w,l=self.setup_loop();other=deepcopy(w.bodies['npc_b']);p=w.packet('npc_a',8)
        c=l.observe(p)['command'];self.assertEqual(c,l.observe(p)['command'])
        r=w.execute(c,p);state=deepcopy(w.bodies);position=deepcopy(w.agents)
        self.assertEqual(w.execute(c,p),r);self.assertEqual(w.bodies,state);self.assertEqual(w.agents,position)
        self.assertEqual(w.bodies['npc_b'],other)
        self.assertTrue(l.result(r)['new_result']);self.assertFalse(l.result(r)['new_result'])
        with self.assertRaises(ValueError):w.execute(dict(c,amount=1),p)

    def test_stale_no_body_cost(self):
        w,l=self.setup_loop();p=w.packet('npc_a',8);c=l.observe(p)['command']
        w.agents['npc_a']['revision']+=1;before=deepcopy(w.bodies)
        r=w.execute(c,p);self.assertEqual(r['status'],'stale');self.assertEqual(before,w.bodies)
        self.assertTrue(l.result(r)['accepted'])

    def test_expired_no_body_cost(self):
        w,l=self.setup_loop();p=w.packet('npc_a',8);c=l.observe(p)['command']
        # Independent World-side expiry check, without altering Runtime's frozen command.
        c=dict(c,expires_us=p['capture_us']+1_000_000);before=deepcopy(w.bodies)
        self.assertEqual(w.execute(c,p)['status'],'expired');self.assertEqual(w.bodies,before)

    def test_sensor_binding_rejection(self):
        w,l=self.setup_loop();p=w.packet('npc_a',8)
        p['locomotor']['source']['agent_id']='npc_b'
        with self.assertRaises(ValueError):l.observe(p)
        self.assertEqual(len(l.agents['npc_a'].observations),0)

    def test_landing_rechecked_by_world(self):
        w,l=self.setup_loop();w.objects=[dict(x=0.,z=.5,height=.4,radius=.1,solid=True,color='gray')]
        p=w.packet('npc_a',8);c=l.observe(p)['command'];self.assertEqual(c['kind'],'climb')
        w.objects.append(dict(x=0.,z=1.,height=.4,radius=.1,solid=True,color='gray'))
        r=w.execute(c,p);self.assertEqual(r['status'],'blocked');self.assertEqual(w.agents['npc_a']['z'],0)
        self.assertTrue(l.result(r)['accepted'])

    def test_saved_replay(self):
        self.assertEqual(json.loads(Path('tests/fixtures/body_exploration.json').read_text(encoding='utf8')),experiment())
