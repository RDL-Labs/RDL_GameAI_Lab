import unittest
from copy import deepcopy
from runtime.initial_orientation import sample, validate, scan
from integrations.lightweight.world import World
from integrations.lightweight.timed_harvest import HarvestCampaign

class InitialOrientationTests(unittest.TestCase):
    def packet(self,yaw=0,slot=4):
        w=World('orientation');w.agents['npc_a']['yaw']=yaw
        p=w.packet('npc_a',slot);p['orientation']=sample(p,yaw);return p
    def test_quantization_wrap_and_day_night(self):
        for yaw in (-720,-181,-180,-15,0,14.9,15,179,180,720):
            p=self.packet(yaw);validate(p)
            error=(p['orientation']['relative_center']+yaw+180)%360-180
            self.assertLessEqual(abs(error),15)
        day=self.packet(42,223);night=self.packet(42,224)
        self.assertEqual(day['orientation']['relative_center'],night['orientation']['relative_center'])
        self.assertNotEqual(day['orientation']['cue'],night['orientation']['cue'])
        self.assertEqual(sample(day,42),day['orientation'])
    def test_binding_and_missing(self):
        p=self.packet();p['orientation']['source']['agent_id']='other'
        with self.assertRaises(ValueError):validate(p)
        p=self.packet();p['orientation']=sample(p,0,False)
        self.assertEqual(scan(p,[])[0],90);self.assertFalse(scan(p,[])[1]['applied'])
    def test_local_history_changes_only_scan_sign(self):
        p=self.packet(0,10);old=self.packet(90,4);before=deepcopy([p,old])
        angle,trace=scan(p,[old]);self.assertEqual(angle,-90)
        self.assertEqual(trace['right_count'],1);self.assertEqual([p,old],before)
        foreign=deepcopy(old);foreign['agent_id']='other'
        self.assertEqual(scan(p,[foreign])[0],90)
        tomorrow=self.packet(0,266)
        self.assertEqual(scan(tomorrow,[old])[0],90)
    def test_runtime_replay_and_nonintervention_without_scan(self):
        w=World('runtime-orientation');aid='npc_a';loop=HarvestCampaign(w.run_id,1,harvest_state=True,mb_field_mode='enabled')
        loop.agents[aid].orientation_mode='enabled'
        loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        p=w.packet(aid,0);p['orientation']=sample(p,w.agents[aid]['yaw'])
        first=loop.observe(p);self.assertEqual(loop.observe(deepcopy(p))['command'],first['command'])
        self.assertEqual(first['command']['kind'],'wait')
        self.assertEqual(loop.agents[aid].learning['records'],[])


    def test_real_three_day_comparison(self):
        import tempfile, json
        from pathlib import Path
        from integrations.lightweight.timed_harvest import run
        streams={}
        with tempfile.TemporaryDirectory() as tmp:
            for mode in ('disabled','enabled'):
                path=Path(tmp)/mode
                summary=run(path,days=3,skyline_subrays=True,stop_after_returns=None,
                    seed=20260930,goal_difference_mode='enabled',food_goal_mode='enabled',
                    lateral_side='left',orientation_mode=mode)
                self.assertEqual(summary['ended_us'],192000000)
                streams[mode]=[json.loads(line) for line in path.read_text().splitlines() if '"type":"decision"' in line]
        reviews=[r for r in streams['enabled'] if r.get('orientation_review')]
        self.assertEqual(len(reviews),4)
        self.assertTrue(any(r['command']['amount']==-90 for r in reviews))
        self.assertTrue(all(r['command']['kind']=='turn' and r['food_review_scans']<=4 for r in reviews))
        by_key=lambda rows:{(r['packet']['agent_id'],r['packet']['capture_us']):r for r in rows}
        old=by_key(streams['disabled'])
        first=next(r for r in reviews if r['command']['amount']==-90)
        baseline=old[(first['packet']['agent_id'],first['packet']['capture_us'])]
        self.assertEqual(baseline['command']['amount'],90)
        self.assertEqual({k:v for k,v in first['packet'].items() if k!='orientation'},baseline['packet'])
