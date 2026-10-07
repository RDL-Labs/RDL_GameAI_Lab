import unittest
from copy import deepcopy
from tests.test_ground_pattern import PatternTests
from tests.test_continuous_selection import context
from runtime.ground_continuity import update,proposals
from runtime.continuous_selection import review


def packet():
    p=PatternTests().packet()
    for i in (6,7,8):p['ground_appearance']['cells'][i]['appearance']='bare_ground'
    return p


def next_packet(p,forward=0,yaw=0):
    q=deepcopy(p);q['observation_id']+='x';q['capture_us']+=250000
    q['pose_ref']+='x';q['body_revision']+=1
    q['ground_appearance']['source']={k:q[k] for k in q['ground_appearance']['source']}
    r=dict(run_id=p['run_id'],agent_id=p['agent_id'],operation_id='op:'+p['observation_id'],
        source_id=p['observation_id'],before_pose_ref=p['pose_ref'],after_pose_ref=q['pose_ref'],
        before_revision=p['body_revision'],after_revision=q['body_revision'],executed_us=p['capture_us']+1,
        status='moved' if forward else 'turned' if yaw else 'waited',forward=forward,right=0,yaw=yaw,acquired=False)
    return q,r


class ContinuityTests(unittest.TestCase):
    def test_unseen_interval_keeps_body_provenance(self):
        p=packet();s=update(p);q,r=next_packet(p)
        for c in q['ground_appearance']['cells']:c.update(status='occluded',appearance=None)
        q['ground_appearance']['coverage']='partial';s=update(q,s,r)
        v,t=next_packet(q);v['ground_appearance']['cells']=deepcopy(p['ground_appearance']['cells'])
        v['ground_appearance']['coverage']='complete';s=update(v,s,t)
        self.assertEqual(len(s['models'][0]['links'][-1]['transforms']),2)

    def test_blocked_continuation_accumulates_H(self):
        a,p,d,r=context('exploration');a.ground_continuity_enabled=True
        v=packet()['ground_appearance'];v['source']={k:p[k] for k in v['source']};p['ground_appearance']=v
        out=review(a,p,d);self.assertEqual(out['continuous_selection']['selected'],'food/ground_1')
        q,r=next_packet(p);r['status']='blocked'
        a.observations={p['observation_id']:p};a.decisions={p['observation_id']:out}
        a.commands={p['observation_id']:dict(operation_id=r['operation_id'])};a.results={r['operation_id']:r}
        later=review(a,q,d);s=later['continuous_selection']
        self.assertEqual(s['nodes']['food/ground_1']['H'],1)
        self.assertNotEqual(s['selected'],'food/ground_1')

    def test_runtime_replay_does_not_reform_models(self):
        from integrations.lightweight.energy_exploration import EnergyWorld,EnergyCampaign
        w=EnergyWorld('r');w.ground_appearance_enabled=True;l=EnergyCampaign('r',1)
        l.configure(dict(w.context('npc_a'),schema=l.schema,clock_id='world-sim-v1',selection_profile='steady',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        a=l.agents['npc_a'];a.continuous_selection=True;a.ground_continuity_enabled=True
        p=w.packet('npc_a',8);first=l.observe(p);state=deepcopy(a.decisions[p['observation_id']])
        replay=l.observe(p);self.assertEqual(replay['command'],first['command']);self.assertEqual(replay['new_frames'],0)
        self.assertEqual(a.decisions[p['observation_id']],state)

    def test_measured_translation_and_replay(self):
        p=packet();s=update(p);before=deepcopy(s);q,r=next_packet(p,.5);t=update(q,s,r)
        self.assertEqual(s,before);self.assertEqual(t['models'][0]['model_ref'],s['models'][0]['model_ref'])
        self.assertTrue(t['models'][0]['extended']);self.assertEqual(len(t['models'][0]['links']),1)
        self.assertEqual(update(q,t,r),t);self.assertEqual(proposals(t,[0]),[('ground_1',0)])

    def test_rotation_uses_measured_result(self):
        p=packet();s=update(p);q,r=next_packet(p,yaw=90)
        for c in q['ground_appearance']['cells']:c['appearance']='grass'
        for i in (0,1,2):q['ground_appearance']['cells'][i]['appearance']='bare_ground'
        t=update(q,s,r);self.assertEqual(len(t['models']),1)
        self.assertEqual(proposals(t,[-90]),[('ground_1',-90)])

    def test_unknown_and_regrowth_are_distinct(self):
        p=packet();s=update(p);q,r=next_packet(p)
        for c in q['ground_appearance']['cells']:c['appearance']='grass'
        self.assertEqual(update(q,s,r)['models'][0]['status'],'observed_context_changed')
        for c in q['ground_appearance']['cells']:c.update(status='occluded',appearance=None)
        q['ground_appearance']['coverage']='partial'
        t=update(q,s,r);self.assertEqual(t['models'][0]['status'],'not_currently_supported');self.assertEqual(proposals(t,[0]),[])

    def test_binding_missing_body_and_ambiguous(self):
        p=packet();s=update(p);q,r=next_packet(p)
        t=update(q,s,None);self.assertEqual(t['models'][0]['model_ref'],'ground_2')
        bad=deepcopy(s);bad['binding']=['other','npc_a']
        with self.assertRaises(ValueError):update(q,bad,r)
        s['models'].append(deepcopy(s['models'][0]));s['models'][1]['model_ref']='ground_2'
        t=update(q,s,r);self.assertIn('ambiguous_correspondence',t['events']);self.assertEqual(proposals(t,[0]),[])

    def test_bounded_history(self):
        p=packet();s=update(p)
        for _ in range(80):q,r=next_packet(p,.5);s=update(q,s,r);p=q
        self.assertLessEqual(len(s['models']),8)
        for m in s['models']:
            self.assertLessEqual(len(m['points']),32);self.assertLessEqual(len(m['links']),16)

    def test_existing_selection_and_safety_gates(self):
        for phase in ('exploration','return','safety','night'):
            a,p,d,r=context(phase);a.ground_continuity_enabled=True
            v=packet()['ground_appearance'];v['source']={k:p[k] for k in v['source']};p['ground_appearance']=v
            out=review(a,p,d);cs=out['continuous_selection']['candidates']
            self.assertEqual(any('/ground_' in c['model'] for c in cs),phase=='exploration')
            if phase=='exploration':self.assertEqual(out['continuous_selection']['selected'],'food/ground_1')

    def test_unknown_ground_never_creates_move(self):
        a,p,d,r=context('exploration');a.ground_continuity_enabled=True
        v=packet()['ground_appearance'];v['source']={k:p[k] for k in v['source']};p['ground_appearance']=v
        for x in p['movement_surface']['ground']['samples']:x['status']='unavailable'
        self.assertFalse(any('/ground_' in c['model'] for c in review(a,p,d)['continuous_selection']['candidates']))
