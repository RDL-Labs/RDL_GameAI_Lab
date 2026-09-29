import unittest
from integrations.lightweight.world import World

class SparseLayoutTests(unittest.TestCase):
    def test_only_world_objects_differ(self):
        dense,sparse=World(),World(layout='sparse')
        self.assertEqual(dense.resources,sparse.resources)
        self.assertEqual(dense.agents,sparse.agents)
        self.assertEqual(sparse.objects,[dense.objects[i] for i in (0,1,4,7,10,14)])
        self.assertEqual(len(sparse.objects),6)
        self.assertEqual(sparse.objects,World(layout='sparse').objects)
        with self.assertRaises(ValueError):World(layout='invalid')
