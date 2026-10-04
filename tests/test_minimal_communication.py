import unittest
from integrations.lightweight.minimal_communication import CommunicationWorld,experiment


class CommunicationTests(unittest.TestCase):
    def world(self):
        w=CommunicationWorld();w.objects=[]
        for a in w.agents.values():a.update(x=0.,z=0.,inventory=0)
        w.agents['npc_b']['inventory']=2
        return w

    def test_five_conditions_and_conservation(self):
        results=experiment()
        self.assertEqual(results['give']['requester_reserve'],70.)
        self.assertEqual(results['give']['consumed'],1)
        self.assertEqual(results['refuse']['requester_messages'][0]['kind'],'refuse')
        self.assertEqual(results['unheard']['requester_messages'],[])
        self.assertEqual(results['warn_stop']['records'][-1]['decision']['action'],'withdraw')
        self.assertEqual(results['warn_continue']['records'][-1]['decision']['action'],'reach')
        for r in results.values():self.assertEqual(sum(r['inventory'].values())+r['consumed'],1)

    def test_reply_binding_replay_and_single_transfer(self):
        w=self.world();w.communicate('npc_a','q','request','npc_b')
        self.assertEqual(w.communicate('npc_b','wrong','give','npc_c','npc_a:q')['status'],'unavailable')
        r=w.communicate('npc_b','give','give','npc_a','npc_a:q')
        self.assertEqual(r['status'],'transferred')
        self.assertEqual(w.communicate('npc_b','give','give','npc_a','npc_a:q'),r)
        self.assertEqual(w.communicate('npc_b','again','give','npc_a','npc_a:q')['status'],'unavailable')
        self.assertEqual(w.agents['npc_a']['inventory'],1)
        with self.assertRaises(ValueError):w.communicate('npc_b','give','wait')

    def test_expired_or_distant_request_cannot_transfer(self):
        for expired in (True,False):
            w=self.world();w.communicate('npc_a','q','request','npc_b')
            if expired:w.seconds=3
            else:w.agents['npc_a']['x']=10
            self.assertEqual(w.communicate('npc_b','g','give','npc_a','npc_a:q')['status'],'unavailable')
            self.assertEqual(w.agents['npc_b']['inventory'],2)

    def test_approach_request_and_reach_are_distinct(self):
        w=self.world()
        self.assertEqual(w.observe_communication('npc_b')['messages'],[])
        w.communicate('npc_a','q','request','npc_b')
        self.assertEqual(w.communicate('npc_b','w','warn','npc_a','npc_a:q')['status'],'unavailable')
        w.communicate('npc_a','r','reach','npc_b')
        self.assertEqual(w.agents['npc_b']['inventory'],2)
        self.assertEqual(w.communicate('npc_b','w2','warn','npc_a','npc_a:r')['status'],'expressed')

    def test_observation_hides_other_body_and_inventory_count(self):
        w=self.world();o=w.observe_communication('npc_a')
        self.assertEqual(set(o['others'][0]),{'ref','holding_food'})
        o['body']['reserve']=0
        self.assertEqual(w.bodies['npc_a']['reserve'],100)
