import unittest
from integrations.lightweight.world import World
from integrations.lightweight.timed_harvest import WorkScheduler
class InexhaustibleTests(unittest.TestCase):
 def test_thirteen_distinct_acquisitions_and_retry(self):
  w=World('stock-test');w.inexhaustible=True;w.objects=[];a=w.agents['npc_a'];w.resources=[dict(x=a['x'],z=a['z']+1,stock=12)];s=WorkScheduler(w)
  for i in range(13):
   p=w.packet('npc_a',4+i*3)
   c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],pose_ref=p['pose_ref'],body_revision=p['body_revision'],capture_us=p['capture_us'],expires_us=p['capture_us']+500001,kind='pickup',amount=0,target_ref=p['food']['visible'][0]['ref'],reason='test')
   s.start(c,p);r=s.advance(p['capture_us']+500000)[0][2];self.assertTrue(r['acquired']);self.assertFalse(s.start(c,p))
  self.assertEqual(a['inventory'],13);self.assertEqual(w.resources[0]['stock'],12);self.assertEqual(len(w.pickups),13)
 def test_finite_is_default(self):self.assertFalse(World().inexhaustible)
