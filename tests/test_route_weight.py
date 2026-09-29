"""Experience competition changes field strength, not stored historical evidence."""
import unittest
from copy import deepcopy
from runtime.relational_movement import route_strength, weight_candidates, review
from tests import test_relational_movement as fixtures


class RouteWeightTests(unittest.TestCase):
    def test_successful_alternative_thins_old_without_erasing_it(self):
        old=dict(support=2,H=0); new=dict(support=1,H=0)
        def compare():
            return weight_candidates([dict(score=route_strength(old)),dict(score=route_strength(new))])
        before=compare(); new['support']=4; after=compare()
        self.assertLess(after[0]['field_weight'],before[0]['field_weight'])
        self.assertGreater(after[1]['share'],after[0]['share'])
        self.assertEqual(old,dict(support=2,H=0))
        self.assertGreater(after[0]['field_weight'],0)

    def test_failure_weakens_even_sole_candidate(self):
        values=[weight_candidates([dict(score=route_strength(dict(support=8,H=h)))])[0]['field_weight'] for h in (0,1,2,32)]
        self.assertTrue(all(a>b for a,b in zip(values,values[1:])))
        self.assertGreater(values[-1],0)

    def test_unused_age_does_not_change_strength(self):
        a=dict(support=2,H=1,last_used=1); b=dict(a,last_used=1000000)
        self.assertEqual(route_strength(a),route_strength(b))

    def test_weakened_route_returns_but_same_day_failure_stays_excluded(self):
        a,p,d,s,r=fixtures.RelationFieldTests().setup()
        key=next(k for k,n in s['routes'].items() if n['goal']=='food')
        s['routes'][key]['H']=32
        out=review(a,p,d)
        self.assertEqual(out['relation_field']['owner'],key)
        self.assertTrue(out['relation_field']['applied'])
        s['failed']=[key]
        self.assertFalse(review(a,p,d)['relation_field']['applied'])

    def test_new_choice_uses_support_but_existing_owner_retained(self):
        a,p,d,s,r=fixtures.RelationFieldTests().setup()
        key=next(k for k,n in s['routes'].items() if n['goal']=='food')
        s['routes']['new']=deepcopy(s['routes'][key]);s['routes']['new']['support']=8
        before=deepcopy(s)
        self.assertEqual(review(a,p,d)['relation_field']['owner'],'new')
        a.decisions['previous']['relation_field']=dict(day=1,phase='exploration',owner=key,operations=0)
        self.assertEqual(review(a,p,d)['relation_field']['owner'],key)
        self.assertEqual(s,before)

    def test_unavailable_alternative_does_not_compete(self):
        a,p,d,s,r=fixtures.RelationFieldTests().setup()
        key=next(k for k,n in s['routes'].items() if n['goal']=='food')
        s['routes']['other']=deepcopy(s['routes'][key]);s['routes']['other']['points'][0]['scene']=[]
        out=review(a,p,d)['relation_field']
        self.assertEqual(len(out['candidates']),1)
        self.assertEqual(out['candidates'][0]['share'],1)

    def test_order_and_empty_and_bounds(self):
        self.assertEqual(weight_candidates([]),[])
        a=[dict(route=str(i),score=route_strength(dict(support=i%9,H=i*2))) for i in range(16)]
        x=weight_candidates(deepcopy(a));y=weight_candidates(list(reversed(deepcopy(a))))
        self.assertAlmostEqual(sum(c['share'] for c in x),1)
        self.assertEqual({c['route']:c['field_weight'] for c in x},{c['route']:c['field_weight'] for c in y})
        self.assertTrue(all(0<c['field_weight']<=1 for c in x))

if __name__=='__main__': unittest.main()
