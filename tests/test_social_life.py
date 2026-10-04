from copy import deepcopy
import gzip
import json
from pathlib import Path
import tempfile
import unittest
from integrations.lightweight.social_life import SocialWorld,SocialCampaign
from integrations.lightweight.social_life_comparison import OPTIONS,audit
from integrations.lightweight.timed_harvest import run
from runtime.social_sleep import ingest,consolidate


class SocialLifeTests(unittest.TestCase):
    def command(self,w,aid,slot,intent):
        p=w.packet(aid,slot)
        c=dict(w.context(aid),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],
               capture_us=p['capture_us'],expires_us=p['capture_us']+1500000,
               pose_ref=p['pose_ref'],body_revision=p['body_revision'],kind='social',amount=0,
               target_ref=json.dumps(intent),reason='social_test')
        return p,c

    def test_transfer_eat_deposit_take_conserve_and_replay(self):
        w=SocialWorld('test');w.objects=[];w.resources=[]
        for b in w.agents.values():b.update(x=0.,z=6.,inventory=0)
        w.agents['npc_b']['inventory']=2
        p,c=self.command(w,'npc_a',0,dict(action='request',target='npc_b'));w.execute(c,p)
        p,c=self.command(w,'npc_b',5,dict(action='give',target='npc_a',reply_to='npc_a:op:test:npc_a:obs:0'))
        r=w.execute(c,p);self.assertEqual(r['status'],'transferred')
        self.assertEqual(w.execute(c,p),r);self.assertEqual(w.agents['npc_a']['inventory'],1)
        p,c=self.command(w,'npc_a',10,dict(action='eat'));w.execute(c,p)
        p,c=self.command(w,'npc_b',10,dict(action='deposit'));w.execute(c,p)
        pa,ca=self.command(w,'npc_a',15,dict(action='take'))
        pc,cc=self.command(w,'npc_c',15,dict(action='take'))
        self.assertEqual(w.execute(ca,pa)['status'],'taken')
        self.assertEqual(w.execute(cc,pc)['status'],'unavailable')
        for ledger in w.food_ledger.values():
            self.assertEqual(sum(ledger['carried'].values())+ledger['shared']+ledger['ground']+ledger['consumed'],2)

    def test_metabolism_is_elapsed_time_not_observation_count(self):
        w=SocialWorld('metabolism');w.advance_metabolism(1000000)
        first=deepcopy(w.bodies);w.advance_metabolism(1000000)
        for aid in w.agents:w.packet(aid,4)
        self.assertEqual(first,w.bodies)
        self.assertEqual(w.bodies['npc_a']['reserve'],99.75)

    def test_only_completed_sleep_adopts_without_support_inflation(self):
        state=dict(records={'m':dict(agent_id='a',target='b',message_id='m',outcome='refuse',tick=1)},
                   model={},cycles=[],pending=None)
        cycle=dict(status='pending',day=0,formation_us=2)
        self.assertEqual(consolidate(state,cycle,'a'),state)
        cycle['status']='completed';one=consolidate(state,cycle,'a')
        self.assertEqual(one['model']['b']['expectation'],1/3)
        self.assertEqual(consolidate(one,cycle,'a'),one)
        cycle['day']=1;two=consolidate(one,cycle,'a')
        self.assertEqual(two['model'],one['model'])
        with self.assertRaises(ValueError):consolidate(state,cycle,'other')

    def test_unexecuted_or_unheard_request_is_not_explicit_refusal(self):
        state=dict(records={},model={},cycles=[],pending=dict(message_id='m',operation_id='op',target='b',deadline=5))
        p=dict(agent_id='a',capture_us=6,observation_id='o',social=dict(messages=[]))
        self.assertEqual(ingest(state,p,{})['records']['m']['outcome'],'request_not_executed')
        r=ingest(state,p,{'op':dict(status='expressed')})
        self.assertEqual(r['records']['m']['outcome'],'no_response_observed')
        self.assertEqual(ingest(r,p,{}),r)

    def test_saved_comparison_next_day_selection_and_sleep_sources(self):
        root=Path('tests/fixtures/social_life')
        report=json.loads((root/'comparison.json').read_text(encoding='utf8'))
        for name,target in [('shadow','npc_b'),('enabled','npc_c')]:
            entry=report[name]
            self.assertTrue(entry['audit']['conserved']);self.assertFalse(entry['audit']['body_overlap'])
            first=next(r for r in entry['audit']['requests'] if r['day']==2 and r['agent']=='npc_a')
            self.assertEqual(first['target'],target)
            for statuses in entry['audit']['sleep_cycles'].values():self.assertEqual(statuses,['completed']*3)
        self.assertGreater(report['shared']['audit']['actions']['take:taken'],0)
        with gzip.open(root/'enabled.jsonl.gz','rt',encoding='utf8') as f:rows=[json.loads(l) for l in f]
        observations={r['packet']['observation_id']:r['packet'] for r in rows if r['type']=='decision'}
        for row in rows:
            if row['type']=='decision' and row.get('social_intent'):
                self.assertEqual(row['command']['kind'],'social')
                self.assertNotIn('trial',row['continuous_selection'])
        for aid,a in report['enabled']['summary']['agents'].items():
            for record in a['social_relations']['records'].values():
                self.assertEqual(observations[record['source_observation_id']]['agent_id'],aid)
            for cycle in a['sleep']['completed']+[a['sleep']['cycle']]:
                for record in cycle['relation_review']['records']:
                    self.assertEqual(record['social_observation'],observations[record['source_observation_id']]['social'])

    def test_packet_binding_and_runtime_replay(self):
        w=SocialWorld('replay');loop=SocialCampaign('replay',1)
        aid='npc_a'
        loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',
            teaching=dict(statement_id='teaching',source='god_statue',sample_observation='sample',
                          appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        p=w.packet(aid,8)
        malformed=deepcopy(p);malformed['social']['source']['agent_id']='npc_b'
        with self.assertRaises(ValueError):loop.observe(malformed)
        first=loop.observe(p);state=deepcopy(loop.agents[aid].learning)
        self.assertEqual(loop.observe(deepcopy(p))['command'],first['command'])
        self.assertEqual(loop.agents[aid].learning,state)

    def test_actual_existing_scheduler_one_day(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'run.jsonl'
            summary=run(path,**dict(OPTIONS,days=1,body_scene='social_shared'))
            checked=audit(path)
            self.assertTrue(checked['conserved']);self.assertFalse(checked['body_overlap'])
            self.assertGreater(summary['pickups'],0)
            self.assertGreater(summary['social_consumed'],0)
