import unittest
from copy import deepcopy
from runtime.food_retention import evaluate
from runtime.refusal_relation_field import choose
from runtime.hunger_review import update


class RetentionTests(unittest.TestCase):
    def choice(self,band='low',reserve=80,H=0,affiliation=0,enabled=True):
        o=dict(self_id='a',food_band=band,inventory=1,body=dict(reserve=reserve),
               others=[dict(ref='b',holding_food=False)],messages=[dict(id='q',sender='b',kind='request')])
        h=update(None,'a',0,reserve,'o');h['goal']['H']=H
        field=dict(owner='a',relations={})
        return choose(field,o,'b','respond',10,affiliation=affiliation,
                      retention=evaluate(o,h) if enabled else None)[1]

    def probability(self,**kwargs):return self.choice(**kwargs)['candidates'][1]['probability']

    def test_scarcity_reserve_H_and_affiliation(self):
        self.assertLess(self.probability(),self.probability(enabled=False))
        self.assertLess(self.probability(),self.probability(band='many'))
        self.assertLess(self.probability(reserve=20,H=2),self.probability(reserve=20))
        p=self.probability(reserve=0,H=2)
        self.assertGreater(p,0);self.assertGreater(self.probability(reserve=0,H=2,affiliation=2),p)
        self.assertEqual(self.choice(),self.choice())

    def test_binding_and_no_state_mutation(self):
        o=dict(self_id='a',food_band='low',body=dict(reserve=50))
        h=update(None,'a',0,50,'o');before=deepcopy(h)
        evaluate(o,h);self.assertEqual(h,before)
        o['self_id']='b'
        with self.assertRaises(ValueError):evaluate(o,h)


if __name__=='__main__':unittest.main()
