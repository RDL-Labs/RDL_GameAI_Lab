from copy import deepcopy
import unittest
from integrations.lightweight.voice_rescue import RescueWorld,experiment,choose


class VoiceRescueTests(unittest.TestCase):
    def test_actual_help_and_rescuer_exhaustion(self):
        good=experiment();bad=experiment(reserve=.15)
        self.assertEqual(good['fed'],1);self.assertEqual(good['inventory']['npc_a'],0)
        self.assertNotIn('npc_b',good['unable_to_walk'])
        self.assertEqual(bad['fed'],0)
        self.assertEqual(bad['unable_to_walk'],['npc_a','npc_b'])
        self.assertTrue(any(r['result']['agent']=='npc_a' and r['result']['distance']>0 for r in bad['records']))
        self.assertTrue(any(r['result']['agent']=='npc_a' and r['decision']['action']=='call' for r in bad['records']))

    def test_sound_range_and_occlusion(self):
        for kwargs in (dict(distance=9),dict(wall=True)):
            report=experiment(**kwargs)
            self.assertEqual(report['fed'],0)
            self.assertFalse(any(r['observation']['heard'] for r in report['records']))

    def test_hearing_has_no_world_identity_or_coordinates(self):
        report=experiment()
        sounds=[s for r in report['records'] for s in r['observation']['heard']]
        self.assertTrue(sounds)
        for sound in sounds:self.assertEqual(set(sound),{'kind','azimuth','range_band','capture_s'})

    def test_replay_and_conflict_do_not_duplicate_food(self):
        w=RescueWorld();w.objects=[]
        for a in w.agents.values():a.update(x=0.,z=0.,inventory=0)
        w.agents['npc_a']['inventory']=1;w.bodies['npc_b']['reserve']=0
        w.act_rescue('npc_b','call','call')
        result=w.act_rescue('npc_a','give','feed','npc_b')
        self.assertEqual(result['status'],'fed')
        saved=deepcopy(w.bodies)
        self.assertEqual(w.act_rescue('npc_a','give','feed','npc_b'),result)
        self.assertEqual(saved,w.bodies);self.assertEqual(w.agents['npc_a']['inventory'],0)
        with self.assertRaises(ValueError):w.act_rescue('npc_a','give','rest')

    def test_expired_call_and_no_remote_feed(self):
        w=RescueWorld();w.objects=[]
        w.agents['npc_a'].update(x=0.,z=0.,inventory=1)
        w.agents['npc_b'].update(x=0.,z=3.)
        w.act_rescue('npc_b','call','call')
        self.assertEqual(w.act_rescue('npc_a','remote','feed','npc_b')['status'],'unavailable')
        w.seconds=2
        self.assertEqual(w.observe_rescue('npc_a')['heard'],[])
        self.assertEqual(choose(w.observe_rescue('npc_a'))['action'],'rest')
