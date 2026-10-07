import json
import tempfile
import unittest
from pathlib import Path
from runtime.personal_food import observe, assess
from integrations.lightweight.social_life import SocialWorld
from integrations.lightweight.social_life_comparison import OPTIONS, audit
from integrations.lightweight.timed_harvest import run


class PersonalFoodTests(unittest.TestCase):
    def test_bands_and_sufficiency_are_separate(self):
        self.assertEqual([observe(n) for n in (0,1,2,3,5,6,20)],
                         ['none','low','low','some','some','many','many'])
        for n in (-1,True,1.5):
            with self.assertRaises(ValueError):observe(n)
        self.assertEqual(assess('many',50)['choice'],'eat')
        self.assertEqual(assess('many',90)['choice'],'provisioned_rest')
        self.assertEqual(assess('some',90),assess(observe(5),90))
        self.assertEqual(assess('low',90)['choice'],'existing_activity')

    def test_world_disallows_shared_transfer_in_personal_mode(self):
        w=SocialWorld('personal');w.personal_food=True;w.objects=[]
        w.agents['npc_a'].update(x=0.,z=6.,inventory=6);w.stock=3
        for slot,action in ((0,'deposit'),(5,'take')):
            p=w.packet('npc_a',slot)
            self.assertEqual(p['social']['food_band'],'many')
            c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],
                capture_us=p['capture_us'],expires_us=p['capture_us']+1500000,pose_ref=p['pose_ref'],
                body_revision=p['body_revision'],kind='social',amount=0,target_ref=json.dumps(dict(action=action)))
            r=w.execute(c,p)
            self.assertEqual(r['status'],'unavailable');self.assertEqual(w.execute(c,p),r)
        self.assertEqual(w.agents['npc_a']['inventory'],6);self.assertEqual(w.stock,3)

    def test_continuous_personal_life_and_sleep(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'life.jsonl'
            run(path,**dict(OPTIONS,body_scene='social_shared',personal_food=True))
            checked=audit(path)
            self.assertTrue(checked['conserved']);self.assertFalse(checked['body_overlap'])
            self.assertNotIn('deposit:deposited',checked['actions'])
            self.assertNotIn('take:taken',checked['actions'])
            decisions=[r for r in map(json.loads,path.read_text().splitlines()) if r['type']=='decision']
            rests=[r for r in decisions if r['command']['reason']=='personal_food_sufficient']
            self.assertTrue(rests)
            for r in rests:
                self.assertEqual(r['command']['kind'],'wait')
                self.assertIn(r['packet']['social']['food_band'],('some','many'))
                self.assertNotIn('trial',r.get('continuous_selection') or {})
            self.assertTrue(any(r.get('social_intent',{}).get('action')=='eat'
                                for r in decisions if r.get('social_intent')))


if __name__=='__main__':unittest.main()
