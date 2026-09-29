import unittest
from copy import deepcopy
from integrations.lightweight.world import World
from integrations.lightweight.timed_harvest import WorkScheduler, HarvestCampaign

class TimedHarvestTests(unittest.TestCase):
    def setup_world(self):
        w=World('work-test');w.objects=[];w.resources=[dict(x=0.,z=1.,stock=1)]
        for a in w.agents.values():a.update(x=0.,z=0.,yaw=0.)
        return w,WorkScheduler(w)
    def command(self,w,aid='npc_a',slot=4):
        p=w.packet(aid,slot);c=dict(w.context(aid),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],capture_us=p['capture_us'],pose_ref=p['pose_ref'],body_revision=p['body_revision'],expires_us=p['capture_us']+500001,kind='pickup',amount=0,target_ref=p['food']['visible'][0]['ref'],reason='test')
        return p,c
    def test_duration_idempotence_and_competition(self):
        w,s=self.setup_world()
        for aid in ('npc_a','npc_b'):
            p,c=self.command(w,aid);self.assertTrue(s.start(c,p));self.assertFalse(s.start(c,p))
        self.assertEqual(s.advance(1499999),[]);self.assertEqual(w.resources[0]['stock'],1)
        results=s.advance(1500000)
        self.assertEqual([r[2]['status'] for r in results],['picked_up','not_found'])
        self.assertEqual(s.advance(1500000),[]);self.assertEqual(w.resources[0]['stock'],0)
        p,c,r=results[0];self.assertFalse(s.start(c,p))
    def test_completion_rechecks_distance_and_pose(self):
        w,s=self.setup_world();p,c=self.command(w);s.start(c,p);w.resources[0]['z']=10
        self.assertEqual(s.advance(1500000)[0][2]['status'],'not_found')
        w,s=self.setup_world();p,c=self.command(w);s.start(c,p);w.agents['npc_a']['revision']+=1
        self.assertEqual(s.advance(1500000)[0][2]['status'],'stale')
    def test_invalid_start(self):
        w,s=self.setup_world();p,c=self.command(w)
        with self.assertRaises(ValueError):s.start(dict(c,expires_us=1500000),p)
        q=deepcopy(p);q['food']['coverage']='partial'
        with self.assertRaises(ValueError):s.start(c,q)
    def test_actual_runtime_local_pickup_and_learning_remains_strict(self):
        w,s=self.setup_world();w.resources[0]['stock']=12;l=HarvestCampaign(w.run_id,1,mb_field_mode='enabled',harvest_state=True)
        aid='npc_a';l.configure(dict(w.context(aid),schema=l.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        for slot in (4,7):
            p=w.packet(aid,slot);p['ground']['coverage']='partial';p['ground']['cells'][1].update(color='unknown',status='occluded')
            c=l.observe(p)['command'];self.assertEqual(c['kind'],'pickup');s.start(c,p)
            result=s.advance(p['capture_us']+500000)[0][2];self.assertTrue(l.result(result)['accepted'])
        self.assertEqual(w.agents[aid]['inventory'],2)
        self.assertEqual(l.agents[aid].learning['records'],[]) # No manufactured complete learning evidence.
        p=w.packet(aid,127);c=l.observe(p)['command'];self.assertEqual(c['kind'],'wait')

    def test_confirmed_unload_releases_capacity_without_erasing_experience(self):
        w,s=self.setup_world();w.resources[0]['stock']=12
        l=HarvestCampaign(w.run_id,2,mb_field_mode='enabled',harvest_state=True)
        aid='npc_a';a=l.agents[aid];a.inventory_capacity=1
        l.configure(dict(w.context(aid),schema=l.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        p=w.packet(aid,4);c=l.observe(p)['command'];s.start(c,p)
        r=s.advance(1500000)[0][2];l.result(r);pickup=r['operation_id']
        self.assertEqual(a.carried_count(),1)
        p=w.packet(aid,7);c=l.observe(p)['command'];self.assertEqual(c['reason'],'inventory_capacity');l.result(w.execute(c,p))
        p=w.packet(aid,224);c=l.observe(p)['command'];r=w.execute(c,p);l.result(r)
        receipt=dict(operation_id=c['operation_id'],executed_us=r['executed_us'],pickups=w.returns[0]['pickups'])
        before=deepcopy(a.results)
        with self.assertRaises(ValueError):a.admit_unload(dict(receipt,pickups=[pickup,'foreign']))
        self.assertEqual(a.carried_count(),1)
        self.assertTrue(a.admit_unload(receipt));self.assertFalse(a.admit_unload(receipt))
        self.assertEqual(a.results,before);self.assertEqual(a.carried_count(),0)
        self.assertEqual(a.snapshot()['inventory'],[])
        self.assertEqual(len(a.snapshot()['unload_receipts']),1)
        with self.assertRaises(ValueError):a.admit_unload(dict(receipt,pickups=[]))
        p=w.packet(aid,260);c=l.observe(p)['command'];self.assertEqual(c['kind'],'pickup')
        s.start(c,p);r=s.advance(p['capture_us']+500000)[0][2];l.result(r)
        self.assertEqual(a.carried_count(),1);self.assertEqual(sum(x['acquired'] for x in a.results.values()),2)

    def test_all_agents_use_same_resource_with_shared_depletion(self):
        w,s=self.setup_world();w.resources[0]['stock']=3
        refs=[]
        for aid in ('npc_a','npc_b','npc_c'):
            p,c=self.command(w,aid);refs.append(c['target_ref']);s.start(c,p)
        self.assertEqual(w.resource_access,'shared-all-agents-v1')
        self.assertEqual(len(set(refs)),3) # Individual observation references, not ownership.
        results=s.advance(1500000)
        self.assertEqual([r[2]['status'] for r in results],['picked_up']*3)
        self.assertEqual(w.resources[0]['stock'],0)
        self.assertEqual([a['inventory'] for a in w.agents.values()],[1,1,1])
        for aid in w.agents:self.assertEqual(w.packet(aid,7)['food']['visible'],[])
        for p,c,r in results:self.assertFalse(s.start(c,p))
        self.assertEqual(w.resources[0]['stock'],0)
