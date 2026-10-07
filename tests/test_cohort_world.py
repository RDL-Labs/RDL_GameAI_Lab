import unittest
from copy import deepcopy
from integrations.lightweight.energy_exploration import EnergyWorld
from integrations.lightweight.resource_regrowth import ResourceRegrowth
from integrations.lightweight.cohort_world import checkpoint,restore


class CohortWorldTests(unittest.TestCase):
    def test_hazard_continuity_and_departed_target(self):
        from integrations.lightweight.territorial_hazard import TerritorialHazard
        from integrations.lightweight.patrol_hazard import PatrolHazard
        old=EnergyWorld('old');old.ground_wear_enabled=False
        t=TerritorialHazard();p=PatrolHazard()
        t.advance(0,old.agents);p.advance(0)
        t.target='npc_a';t.mode='approaching'
        s=checkpoint(old,None,t,p,250000)
        new=EnergyWorld('new');new.ground_wear_enabled=False
        nt=TerritorialHazard();np=PatrolHazard()
        restore(new,None,nt,np,s)
        self.assertIsNone(nt.target)
        self.assertEqual(nt.mode,'returning')
        self.assertEqual(np.body,p.body)
        self.assertEqual(np.advance(250000)['capture_us'],250000)
        self.assertEqual(nt.advance(250000,new.agents)['capture_us'],250000)

    def test_transfer_and_control(self):
        old=EnergyWorld('old');old.ground_wear_enabled=True
        old.ground_wear.recovery_enabled=True
        old.ground_wear.walk('op','npc_a',(0,0),(1,0))
        reg=ResourceRegrowth(3);reg.advance(1919750000,old.resources)
        old.ground_wear.advance(1919750000)
        old.resources[0]['stock']=2
        s=checkpoint(old,reg,None,None,1920000000);before=deepcopy(s)
        worlds=[]
        for reset in (False,True):
            w=EnergyWorld('new');w.ground_wear_enabled=True;w.ground_wear.recovery_enabled=True
            r=ResourceRegrowth(3)
            self.assertEqual(restore(w,r,None,None,s,reset),1920000000)
            self.assertEqual(w.resources,s['resources'])
            self.assertEqual(w.ground_wear.operations,{})
            self.assertIsNot(w.ground_wear.cells,s['ground']['cells'])
            self.assertEqual(r.advance(1920000000,w.resources)['epoch'],10)
            worlds.append(w)
        self.assertEqual(worlds[0].resources,worlds[1].resources)
        self.assertEqual(s,before)

    def test_wear_is_only_control_difference(self):
        old=EnergyWorld('old');old.ground_wear_enabled=True
        old.ground_wear.walk('op','npc_a',(0,0),(1,0))
        s=checkpoint(old,None,None,None,250000)
        worlds=[]
        for reset in (False,True):
            w=EnergyWorld('new');w.ground_wear_enabled=True
            restore(w,None,None,None,s,reset);worlds.append(w)
        a,b=[w.ground_wear.snapshot() for w in worlds]
        self.assertGreater(sum(c['wear'] for c in a['cells'].values()),0)
        for c in a['cells'].values():c['wear']=0
        self.assertEqual(a,b)
        self.assertEqual(worlds[0].agents,worlds[1].agents)

    def test_invalid_reset(self):
        with self.assertRaises(ValueError):restore(EnergyWorld("new"),None,None,None,None,True)

