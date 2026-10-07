import unittest
from runtime.hunger_review import update,select


class HungerTests(unittest.TestCase):
    def test_life_food_conservation_with_hunger(self):
        import tempfile
        from pathlib import Path
        from integrations.lightweight.timed_harvest import run
        from integrations.lightweight.social_life_comparison import OPTIONS,audit
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'life.jsonl'
            run(path,**dict(OPTIONS,body_scene='social_shared',personal_food=True,hunger_enabled=True))
            result=audit(path)
            self.assertTrue(result['conserved'])
            self.assertNotIn('deposit:deposited',result['actions'])

    def test_onset_and_gradient(self):
        values=[update(None,'a',0,x,'o')['intensity'] for x in (81,80,60,0)]
        self.assertEqual(values[0],0);self.assertGreater(values[1],0)
        self.assertEqual(values,sorted(values))

    def test_time_bound_pressure_and_recovery(self):
        s=update(None,'a',0,80,'o0')
        self.assertEqual(select(s,'eat')['selected'],'existing_activity')
        for t in range(1,5):s=update(s,'a',t*1000000,79,'o'+str(t))
        self.assertEqual(s['goal']['H'],0)
        s=update(s,'a',5000000,79,'o5')
        self.assertEqual(s['goal']['H'],1)
        self.assertEqual(select(s,'eat')['selected'],'eat')
        self.assertEqual(update(s,'a',5000000,79,'o5'),s)
        s=update(s,'a',10000000,90,'o10')
        self.assertEqual(s['goal']['H'],0);self.assertEqual(s['intensity'],0)
        with self.assertRaises(ValueError):update(s,'b',10000001,70,'bad')


if __name__=='__main__':unittest.main()
