import unittest
from copy import deepcopy
from runtime.landmark_return_campaign import ReturnCampaign, SCHEMA
from runtime.multi_resource_exploration import MultiResourceExploration
from test_model_movement_field import CampaignSession
from test_resource_exploration import config
from test_return_campaign import action,world
from integrations.luanti.tests.check_return_campaign import trips


class SixAgentCampaignTests(unittest.TestCase):
    def sessions(self):
        loop=ReturnCampaign('r',3,agent_count=6,mb_field_mode='enabled',harvest_state=True)
        sessions=[]
        for aid in loop.agents:
            c=config();c.update(schema=SCHEMA,agent_id=aid,selection_profile='steady',agent_count=6,mb_field_mode='enabled')
            loop.configure(c)
            s=object.__new__(CampaignSession);s.multi=loop;s.agent=aid;s.loop=loop.agents[aid]
            s.seq=4;s.revision=0;s.pose='r:'+aid+':pose:0';sessions.append(s)
        return loop,sessions

    def test_six_independent_learners_and_replay(self):
        loop,ss=self.sessions()
        for s in ss:
            s.learn();p=s.packet(False);s.apply(p)
            before=s.loop.snapshot();reply=loop.observe(p)
            self.assertEqual(reply['new_observations'],0)
            self.assertEqual(s.loop.snapshot(),before)
            self.assertTrue(s.loop.learning['invalidated'])
            self.assertTrue(all(r['agent_id']==s.agent for r in s.loop.learning['records']))
            self.assertEqual(s.loop.model.agent_id,s.agent)
        ids=[set(s.loop.results) for s in ss]
        self.assertEqual(len(set.union(*ids)),sum(map(len,ids)))
        self.assertEqual(loop.snapshot()['agent_count'],6)

    def test_cross_agent_packets_and_population_conflict_are_atomic(self):
        loop,ss=self.sessions();p=ss[0].packet();p['agent_id']='npc_f'
        before=loop.snapshot()
        with self.assertRaisesRegex(ValueError,'cross_agent'):loop.observe(p)
        self.assertEqual(before,loop.snapshot())
        c=config();c.update(schema=SCHEMA,selection_profile='steady',mb_field_mode='enabled')
        with self.assertRaisesRegex(ValueError,'population_binding'):loop.configure(c)
        self.assertEqual(before,loop.snapshot())
        self.assertEqual(len(MultiResourceExploration('r').agents),3)
        for n in (True,0,4,7):
            with self.assertRaises(ValueError):ReturnCampaign('r',agent_count=n)

    def test_six_return_batches_not_three_or_six_items(self):
        w=world();w['return_campaign']={'target':6}
        for day in range(7):
            w['agents']['npc_a']['actions'].append(action(day))
            w['stock_events'].append(dict(agent_id='npc_a',operation_id='pick'+str(day),executed_us=day*64000000+10))
        self.assertEqual(len(trips(w)),6)
        w['return_campaign']['target']=3
        self.assertEqual(len(trips(w)),3)
