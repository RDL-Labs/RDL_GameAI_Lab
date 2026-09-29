import unittest
from integrations.lightweight.world import World
class SkylineSubrayTests(unittest.TestCase):
 def test_gap_capture_preserves_other_channels(self):
  w=World(layout='sparse');w.agents['npc_c'].update(x=-14.435028842544407,z=-9.435028842544405,yaw=0.)
  p=w.packet('npc_c',128);w.skyline_subrays=True;q=w.packet('npc_c',128)
  self.assertFalse(any(x['color']=='ochre' for x in p['skyline']['features']))
  self.assertTrue(any(x['color']=='ochre' for x in q['skyline']['features']))
  self.assertEqual({k:v for k,v in p.items() if k!='skyline'},{k:v for k,v in q.items() if k!='skyline'})
  self.assertLessEqual(len(q['skyline']['features']),39)
 def test_subrays_do_not_see_through_wall(self):
  w=World();w.skyline_subrays=True;w.agents['npc_a'].update(x=0.,z=0.,yaw=0.)
  w.objects=[dict(x=0.,z=20.,radius=1.,height=12.,color='ochre',solid=True),dict(x=0.,z=10.,radius=4.,height=30.,color='gray',solid=True)]
  self.assertFalse(any(x['color']=='ochre' for x in w.packet('npc_a',0)['skyline']['features']))
