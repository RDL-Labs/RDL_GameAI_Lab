import copy
import gzip
import json
import unittest
from pathlib import Path
from types import SimpleNamespace

from runtime.reversal_review import review
from runtime.reversal_review_loop import review_loop


def pending_case():
    pending = dict(source='o1',capture_us=1000000,sample_seq=4,pose_ref='p1',body_revision=1,
                   approach=dict(ref='food',operations=5),turn_amount=90,turns_without_move=1)
    a = SimpleNamespace(reversal_review_mode='enabled',decisions={'o1':dict(period=0,
        reversal_review=dict(state=dict(used=True,pending=pending)))},
        results={'op:o1':dict(status='waited',after_pose_ref='p1',after_revision=1,executed_us=1020000)})
    p = dict(observation_id='o2',capture_us=1250000,sample_seq=5,pose_ref='p1',body_revision=1)
    d = dict(period=0,approach=dict(ref='food',operations=5),blocked_targets=[],
             movement_terrain=dict(status='complete'),action=['turn',-45],reason='current_terrain',target='')
    return a,p,d


class ReversalReviewTests(unittest.TestCase):
    def test_wait_does_not_erase_turn_anchor(self):
        a,p,d = pending_case()
        before = copy.deepcopy(a.decisions)
        out = review(a,p,d)
        self.assertEqual(out['action'], ['wait',0])
        self.assertEqual(out['reversal_review']['status'], 'same_reversal_deferred')
        self.assertIsNone(out['reversal_review']['state']['pending'])
        self.assertEqual(out['blocked_targets'], ['food'])
        self.assertEqual(a.decisions, before)

    def test_changed_current_selection_can_release_without_inventing_action(self):
        for action in (['move',1], ['turn',45], ['pickup',0]):
            a,p,d = pending_case(); d['action'] = action
            out = review(a,p,d)
            self.assertEqual(out['action'], action)
            self.assertEqual(out['blocked_targets'], [])
            self.assertIn(out['reversal_review']['status'], ('released_to_existing_control','pickup_priority'))

    def test_turn_count_and_exhausted_permission_are_preserved(self):
        a,p,d = pending_case(); d.update(action=['turn',45],steering=dict(turns_without_move=0))
        self.assertEqual(review(a,p,d)['steering']['turns_without_move'],1)
        a,p,d = pending_case()
        a.decisions['o1']['reversal_review']['state']['pending'] = None
        d.update(action=['wait',0],reason='observed_material_terrain_reversal_stopped',
                 steering=dict(stopped_approach=dict(ref='food')),blocked_targets=['food'])
        out=review(a,p,d)
        self.assertEqual(out['blocked_targets'],['food'])
        self.assertIsNone(out['reversal_review']['state']['pending'])

    def test_unknown_pose_expiry_and_partial_defer(self):
        for change in ('pose','time','result','partial'):
            a,p,d = pending_case()
            if change == 'pose': p['pose_ref'] = 'changed'
            if change == 'time': p['capture_us'] = 1600000
            if change == 'result': a.results = {}
            if change == 'partial': d['movement_terrain']['status'] = 'partial'
            out = review(a,p,d)
            self.assertEqual(out['action'], ['wait',0])
            self.assertNotEqual(out['reversal_review']['status'],'released_to_existing_control')

    def test_other_target_priority_preserved(self):
        a,p,d = pending_case();d.update(approach=dict(ref='other'),action=['pickup',0],target='other')
        out=review(a,p,d)
        self.assertEqual(out['action'],['pickup',0])
        self.assertEqual(out['target'],'other')
        self.assertEqual(out['blocked_targets'],['food'])

    def test_actual_replay_resend_and_finite_review(self):
        with gzip.open(Path(__file__).parent/'fixtures/luanti_l15a_reversal_review.json.gz','rt',encoding='utf-8') as f:
            report=json.load(f)
        self.assertEqual(len(report['runs']),2)
        for item in report['runs']:
            data=item['data'];s=data['runtime']['exploration']
            loop=review_loop(32)(s['run_id'],s['periods'],s['seed'],s['assignment'])
            for wire in data['world']['deliveries']:
                response=getattr(loop,wire['kind'])(wire['request'])
                self.assertEqual(response,json.loads(wire['response_wire']))
                if (wire['kind']=='observe' and wire['request']['agent_id']=='npc_b'
                        and wire['request']['sample_seq'] in (64,65)):
                    before=loop.snapshot()
                    replay=loop.observe(wire['request'])
                    self.assertEqual(replay['command'],response['command'])
                    self.assertEqual((replay['new_observations'],replay['new_frames']),(0,0))
                    self.assertEqual(loop.snapshot(),before)
            for a in loop.snapshot()['agents'].values():
                reviews=[d['reversal_review'] for d in a['decisions'].values()]
                self.assertLessEqual(sum(m['status']=='awaiting_next_observation' for m in reviews),1)
                self.assertLessEqual(sum(m['status']=='same_reversal_deferred' for m in reviews),1)
            b=loop.snapshot()['agents']['npc_b']
            ds=list(b['decisions'].values())
            mode=s['reversal_review_modes']['npc_b']
            if mode=='enabled':
                self.assertEqual(ds[64]['reversal_review']['status'],'awaiting_next_observation')
                self.assertEqual(ds[64]['blocked_targets'],[])
                self.assertEqual(ds[65]['reversal_review']['status'],'same_reversal_deferred')
                self.assertEqual(len(ds[65]['blocked_targets']),1)
            else:
                self.assertEqual(len(ds[64]['blocked_targets']),1)
            config=copy.deepcopy(next(w['request'] for w in data['world']['deliveries'] if w['kind']=='configure'))
            before=loop.snapshot()
            config['reversal_review_mode']='disabled' if config['reversal_review_mode']=='enabled' else 'enabled'
            with self.assertRaises(ValueError):loop.configure(config)
            self.assertEqual(loop.snapshot(),before)
