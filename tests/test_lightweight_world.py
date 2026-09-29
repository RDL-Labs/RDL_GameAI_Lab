import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from integrations.lightweight.world import World, run


def command(w, p, kind, target=''):
    return dict(w.context(p['agent_id']),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],
        pose_ref=p['pose_ref'],body_revision=p['body_revision'],capture_us=p['capture_us'],expires_us=p['capture_us']+500000,
        kind=kind,amount=90 if kind=='turn' else 1 if kind=='move' else 0,target_ref=target,reason='test')


class LightweightWorldTests(unittest.TestCase):
    def setUp(self):
        self.w=World();self.w.objects=[];self.w.resources=[]
        for a in self.w.agents.values():a.update(x=0.,z=0.,yaw=0.)

    def test_occlusion_and_hidden_world_changes(self):
        w=self.w;w.resources=[dict(x=0.,z=4.,stock=2)]
        w.objects=[dict(x=0.,z=2.,radius=.5,height=3.,color='gray',solid=True)]
        p=w.packet('npc_a',0);self.assertEqual(p['food']['visible'],[])
        w.resources[0]['stock']=9
        self.assertEqual(p,w.packet('npc_a',0))
        w.objects=[];p=w.packet('npc_a',0)
        self.assertEqual(len(p['food']['visible']),1)
        self.assertNotIn('stock',json.dumps(p));self.assertNotIn('"x"',json.dumps(p))
        self.assertNotEqual(p['food']['visible'][0]['ref'],w.packet('npc_b',0)['food']['visible'][0]['ref'])

    def test_swept_collision_and_operation_replay(self):
        w=self.w;w.objects=[dict(x=0.,z=.5,radius=.1,height=3.,color='gray',solid=True)]
        p=w.packet('npc_a',0);c=command(w,p,'move');r=w.execute(c,p)
        self.assertEqual(r['status'],'blocked');self.assertEqual(w.agents['npc_a']['z'],0)
        self.assertEqual(w.execute(c,p),r)
        w.objects=[];p=w.packet('npc_a',1);c=command(w,p,'move');r=w.execute(c,p)
        self.assertEqual(r['status'],'moved');w.execute(c,p)
        self.assertEqual(w.agents['npc_a']['z'],1)
        altered=dict(c,amount=2)
        with self.assertRaisesRegex(ValueError,'conflict'):w.execute(altered,p)

    def test_competing_pickups_depletion_and_one_return(self):
        w=self.w;w.resources=[dict(x=0.,z=1.,stock=1)]
        packets={aid:w.packet(aid,224) for aid in w.agents}
        results=[w.execute(command(w,p,'pickup',p['food']['visible'][0]['ref']),p) for p in packets.values()]
        self.assertEqual([r['status'] for r in results],['picked_up','not_found','not_found'])
        self.assertEqual(w.resources[0]['stock'],0)
        self.assertEqual(w.packet('npc_a',225)['food']['visible'],[])
        p=w.packet('npc_a',225);c=command(w,p,'wait');w.execute(c,p);w.execute(c,p)
        p=w.packet('npc_a',226);w.execute(command(w,p,'wait'),p)
        self.assertEqual(len(w.returns),1);self.assertEqual(w.agents['npc_a']['inventory'],0)

    def test_stale_and_cross_agent_do_not_act(self):
        w=self.w;p=w.packet('npc_a',0);c=command(w,p,'turn');w.agents['npc_a']['revision']=1
        self.assertEqual(w.execute(c,p)['status'],'stale');self.assertEqual(w.agents['npc_a']['yaw'],0)
        with self.assertRaises(ValueError):w.execute(dict(c,agent_id='npc_b'),p)

    def test_tower_range_and_height_occlusion(self):
        w=self.w;w.objects=[dict(x=0.,z=7.,radius=1.,height=12.,color='ochre',solid=True)]
        self.assertTrue(any(f['elevation']==30 for f in w.packet('npc_a',0)['skyline']['features']))
        w.objects.insert(0,dict(x=0.,z=3.,radius=1.,height=20.,color='gray',solid=True))
        self.assertFalse(any(f['color']=='ochre' for f in w.packet('npc_a',0)['skyline']['features']))
        w.objects=w.objects[1:];w.objects[0]['z']=60
        self.assertEqual(w.packet('npc_a',0)['skyline']['features'],[])

    def test_same_seed_replays_and_existing_runtime_accepts(self):
        with tempfile.TemporaryDirectory() as tmp:
            a,b=Path(tmp)/'a.jsonl',Path(tmp)/'b.jsonl'
            x=run(a,days=1);y=run(b,days=1)
            rows=lambda p:[json.loads(line) for line in p.read_text().splitlines()]
            left,right=rows(a),rows(b)
            left[-1].pop('elapsed_seconds');right[-1].pop('elapsed_seconds')
            self.assertEqual(left,right)
            self.assertEqual(x['slots'],256)
            self.assertEqual(len([r for r in left if r['type']=='step']),768)
            self.assertTrue(all(s['observations']==256 for s in x['agents'].values()))
            self.assertNotEqual(World(seed=1).objects,World(seed=2).objects)
