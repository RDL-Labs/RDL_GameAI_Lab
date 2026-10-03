import unittest
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
from copy import deepcopy
from integrations.lightweight.resource_regrowth import ResourceRegrowth,DAY_US
from integrations.lightweight.world import World


class RegrowthTests(unittest.TestCase):
    def test_stock_audit_counts_supply_and_rejects_forged_supply(self):
        from integrations.lightweight.finite_territory_comparison import stock_audit
        resources=[dict(x=0,z=0,stock=0),dict(x=5,z=0,stock=12)]
        event=ResourceRegrowth(3).advance(3*DAY_US,deepcopy(resources))
        report=dict(manifest=dict(stock_mode='finite',inexhaustible_after_model=False,regrowth_days=3,resources=resources),
            territory_config=dict(center=[0,0],radius=1),summary=dict(stock=[12,12],pickups=0,ended_us=4*DAY_US,agents={'a':dict(carried=0,unloaded=0)}))
        completed=dict(type='completed',result=dict(executed_us=3*DAY_US+1,acquired=False,status='waited'),stock=[12,12])
        with TemporaryDirectory() as temp:
            path=Path(temp)/'audit.jsonl'
            def write():path.write_text('\n'.join(json.dumps(x) for x in (event,completed)),encoding='utf8')
            write()
            with patch('integrations.lightweight.finite_territory_comparison.inspect',return_value=(deepcopy(report),[])):
                self.assertEqual(stock_audit(path)[0]['finite_resources']['total_added'],12)
            event['added'][0]=13;write()
            with patch('integrations.lightweight.finite_territory_comparison.inspect',return_value=(deepcopy(report),[])):
                with self.assertRaises(AssertionError):stock_audit(path)

    def test_time_boundary_capacity_and_no_duplicate(self):
        r=ResourceRegrowth(3);stock=[dict(stock=0),dict(stock=5),dict(stock=12)]
        self.assertIsNone(r.advance(3*DAY_US-1,stock))
        e=r.advance(3*DAY_US,stock)
        self.assertEqual(e['added'],[12,7,0]);self.assertEqual(e['stock'],[12]*3)
        stock[0]['stock']=11
        self.assertIsNone(r.advance(3*DAY_US,stock));self.assertEqual(stock[0]['stock'],11)
        self.assertEqual(r.advance(6*DAY_US,stock)['added'],[1,0,0])
        with self.assertRaises(ValueError):r.advance(0,stock)

    def test_invalid_configuration(self):
        for days in (0,-1,True,1.5):
            with self.assertRaises(ValueError):ResourceRegrowth(days)

    def test_depleted_food_reappears_only_in_current_view(self):
        w=World('regrowth-view');w.objects=[];w.agents['npc_a'].update(x=0,z=0,yaw=0)
        w.resources=[dict(x=0,z=2,stock=0)]
        before=w.packet('npc_a',0)
        self.assertEqual(before['food']['visible'],[])
        ResourceRegrowth(1).advance(DAY_US,w.resources)
        after=w.packet('npc_a',256)
        self.assertTrue(after['food']['visible'])
        self.assertNotIn('regrowth',after)
        self.assertEqual(before['food']['visible'],[])


if __name__=='__main__':unittest.main()
