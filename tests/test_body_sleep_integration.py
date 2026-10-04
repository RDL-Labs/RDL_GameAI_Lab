from copy import deepcopy
import gzip
import json
from pathlib import Path
import tempfile
import unittest

from integrations.lightweight.body_exploration import ExplorationBodyWorld, BodyScheduler
from integrations.lightweight.body_sleep_comparison import audit
from integrations.lightweight.timed_harvest import run
from runtime.layered_body import initial
from runtime.sleep_auto_model import adopt, apply


class BodySleepIntegrationTests(unittest.TestCase):
    def command(self,w,slot,kind='wait',reason='test',target=''):
        p=w.packet('npc_a',slot)
        c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],
               capture_us=p['capture_us'],pose_ref=p['pose_ref'],body_revision=p['body_revision'],
               expires_us=p['capture_us']+1_500_000,kind=kind,amount=0,target_ref=target,reason=reason)
        return p,c

    def test_scheduler_does_not_execute_early_or_twice(self):
        w=ExplorationBodyWorld('s');w.objects=[];w.bodies['npc_a']['burst']=0
        s=BodyScheduler(w);p,c=self.command(w,8)
        before=deepcopy(w.bodies)
        self.assertTrue(s.start(c,p));self.assertFalse(s.start(c,p))
        self.assertEqual(s.advance(2_999_999),[]);self.assertEqual(w.bodies,before)
        self.assertEqual(len(s.advance(3_000_000)),1)
        self.assertEqual(w.bodies['npc_a']['burst'],2)
        self.assertFalse(s.start(c,p));self.assertEqual(s.advance(4_000_000),[])
        with self.assertRaises(ValueError):s.start(dict(c,reason='changed'),p)
        self.assertEqual(w.bodies['npc_b'],before['npc_b'])

    def test_real_stock_unload_and_replay(self):
        w=ExplorationBodyWorld('u');w.objects=[];w.resources=[dict(x=0.,z=6.8,stock=1)]
        w.agents['npc_a'].update(x=0.,z=6.,yaw=0.)
        p,c=self.command(w,8,'pickup');c['target_ref']=p['food']['visible'][0]['ref']
        self.assertTrue(w.execute(c,p)['acquired']);self.assertEqual(w.agents['npc_a']['inventory'],1)
        p,c=self.command(w,16,reason='return_unload_attempt')
        r=w.execute(c,p);self.assertEqual(w.agents['npc_a']['inventory'],0)
        self.assertEqual(len(w.returns),1);self.assertEqual(len(w.returns[0]['pickups']),1)
        self.assertEqual(w.execute(c,p),r);self.assertEqual(len(w.returns),1)
        p,c=self.command(w,24,reason='return_unload_attempt');w.execute(c,p)
        self.assertEqual(len(w.returns),1)

    def test_three_days_live_sleep_unload_and_body_sources(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'run.jsonl'
            result=run(path,days=3,stop_after_returns=None,body_mode='enabled',body_scene='food_barrier',
                       sleep_learning=True,sleep_auto_adopt=True,selection_mode='continuous',
                       return_completion_mode='enabled',orientation_mode='enabled',skyline_subrays=True,seed=20261002)
            report=audit(path)
        self.assertEqual(result['pickups'],36)
        self.assertEqual(sum(len(r['pickups']) for r in result['returns']),12)
        self.assertEqual(report['duplicate_effects'],0);self.assertTrue(report['body_continuity'])
        self.assertEqual(report['body_sleep_sources']['climb'],3)
        self.assertEqual(report['body_sleep_sources']['pickup'],3)
        self.assertEqual(len(report['night_cycles']),9)
        self.assertTrue(all(n['status']=='completed' and n['rest_us']==1_000_000 for n in report['night_cycles']))
        self.assertEqual(sum(s['carried'] for s in result['agents'].values()),24)

    def test_saved_logs_audit_and_source_provenance(self):
        root=Path('tests/fixtures/body_sleep')
        comparison=json.loads((root/'comparison.json').read_text(encoding='utf8'))
        for name,entry in comparison.items():
            with gzip.open(root/(name+'.jsonl.gz'),'rt',encoding='utf8') as stream:
                rows=[json.loads(line) for line in stream]
            completed={r['result']['operation_id']:r for r in rows if r['type']=='completed'}
            for agent in entry['summary']['agents'].values():
                if not agent['sleep']:continue
                cycles=agent['sleep']['completed']+[agent['sleep']['cycle']]
                for cycle in cycles:
                    if not cycle:continue
                    for record in cycle['relation_review']['records']:
                        source=completed[record['record_id']]
                        self.assertEqual(record['body_observation'],source['packet']['locomotor'])
                        self.assertEqual(record['action'],source['command']['kind'])
                        self.assertEqual(record['outcome'],source['result']['status'])
            with tempfile.TemporaryDirectory() as folder:
                p=Path(folder)/'r.jsonl';p.write_text('\n'.join(json.dumps(r) for r in rows),encoding='utf8')
                self.assertEqual(audit(p),entry['audit'])

    def test_body_conditions_do_not_mix_in_sleep_bias(self):
        r=dict(record_id='r',agent_id='a',tick=1,food_coverage='complete',hazard_coverage='complete',
               food_seen=True,hazard_seen=False,action='move',amount=.5,outcome='moved',
               body_observation=dict(state=initial(),front_height_upper=0.))
        model=adopt(None,dict(records=[r]),'run','a',2)
        self.assertEqual(adopt(model,dict(records=[r]),'run','a',3)['cells'][0]['support'],1)
        class Agent:pass
        a=Agent();a._prospective=({'sleep_auto_model':model},None)
        p=dict(run_id='run',agent_id='a',capture_us=4,food=dict(coverage='complete',visible=[{}]),
               hazard=dict(coverage='complete',features=[]),locomotor=deepcopy(r['body_observation']))
        candidates=[dict(action=['move',.5],model='m',score=0.)]
        self.assertEqual(apply(a,p,candidates)['status'],'applied')
        p['locomotor']['state']['burst']=0
        self.assertEqual(apply(a,p,candidates)['status'],'no_matching_cell')
        del p['locomotor']
        self.assertEqual(apply(a,p,candidates)['status'],'no_matching_cell')
