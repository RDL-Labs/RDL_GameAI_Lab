import copy
import gzip
import json
import unittest
from runtime.landmark_return_campaign import ReturnCampaign,admission_fork
from integrations.luanti.tests.check_return_campaign import trips
from integrations.luanti.tests.check_multi_resource import first_difference


def action(day,agent="npc_a",x=0,seq=0):
    op=f"{agent}:night:{day}:{seq}"
    return dict(command=dict(capture_us=day*64000000+56000000,operation_id=op),
        result=dict(status="waited",executed_us=day*64000000+56010000+seq),
        after=dict(position=dict(x=x,y=0,z=6)))


def world(): return dict(agents={"npc_a":dict(actions=[])},stock_events=[])


class CampaignTests(unittest.TestCase):
    def test_day_bound_and_three_day_wire_equivalence(self):
        for n in (0,91,True):
            with self.assertRaises(ValueError):ReturnCampaign("r",n)
        ReturnCampaign("r",30)
        extended=ReturnCampaign("extended",90)
        self.assertEqual(extended.agents["npc_a"].limit_us,90*64000000)
        with gzip.open("tests/fixtures/luanti_l15a_landmark_day_cycle.json.gz","rt",encoding="utf-8") as f:
            data=json.load(f)["runs"][0]["data"]
        w=data["world"];loop=ReturnCampaign(w["run_id"],3)
        for entry in w["deliveries"]:
            p=copy.deepcopy(entry["request"])
            if entry["kind"]=="configure":p["schema"]=loop.schema
            self.assertEqual(getattr(loop,entry["kind"])(p),json.loads(entry["response_wire"]))
        s=loop.snapshot();s["schema"]=data["runtime"]["exploration"]["schema"]
        # Derived terrain diagnostics may differ by platform rounding; raw
        # observations, commands and discrete choices still compare exactly.
        difference=first_difference(s,data["runtime"]["exploration"])
        self.assertIsNone(difference,difference)
        store=loop.agents["npc_a"].store
        fork=admission_fork(store);before=store.snapshot()
        fork.record_rejection({"agent_id":"npc_a","observation_id":"bad"},ValueError("bad"))
        self.assertEqual(store.snapshot(),before)
        snapshot=fork.snapshot();snapshot["frames"][0]["payload"]["features"].clear()
        self.assertEqual(store.snapshot(),before)
        frame=copy.deepcopy(before["frames"][-1])
        frame.pop("run_id");frame.pop("world_epoch")
        frame["frame_id"]="new-frame";frame["sample_seq"]+=1;frame["sampled_world_tick"]+=1
        frame["capture_window"]["start_us"]+=250000;frame["capture_window"]["end_us"]+=250000
        extension=dict(schema_version=before["schema_version"],run_id=store.run_id,world_epoch=1,agent_id="npc_a",
            delivery_observation_id="new-observation",delivery_world_tick=frame["sample_seq"],
            delivery_time_us=frame["capture_window"]["end_us"],frames=[frame])
        packet=dict(agent_id="npc_a",observation_id="new-observation",tick=frame["sample_seq"])
        with self.assertRaises(ValueError):fork.admit(packet,extension)  # capacity failure stays isolated
        self.assertEqual(store.snapshot(),before)
        fork.capacity+=1
        self.assertEqual(fork.admit(packet,extension)["new_frames"],1)
        self.assertEqual(store.snapshot(),before)
        self.assertEqual(fork.admit(packet,extension)["new_frames"],0)
        self.assertIsNot(fork._frames,store._frames)
        self.assertIsNot(next(iter(fork._frames.values())),next(iter(store._frames.values())))

    def test_empty_and_same_inventory_never_add_trips(self):
        w=world();w["agents"]["npc_a"]["actions"]=[action(0),action(1),action(2)]
        self.assertEqual(trips(w),[])
        w["stock_events"]=[dict(agent_id="npc_a",operation_id="pick",executed_us=10)]
        self.assertEqual(len(trips(w)),1)
        self.assertEqual(trips(w)[0]["pickup_operations"],["pick"])

    def test_batch_not_quantity_and_outside_home_not_return(self):
        w=world();w["agents"]["npc_a"]["actions"]=[action(0,x=11),action(1),action(1,seq=1)]
        w["stock_events"]=[dict(agent_id="npc_a",operation_id=f"pick{i}",executed_us=10+i) for i in range(12)]
        t=trips(w);self.assertEqual(len(t),1);self.assertEqual(t[0]["day"],2)
        self.assertEqual(len(t[0]["pickup_operations"]),12)

    def test_new_batches_and_aggregate_limit(self):
        w=world()
        w["agents"]["npc_a"]["actions"]=[action(d) for d in range(4)]
        w["stock_events"]=[dict(agent_id="npc_a",operation_id=f"pick{d}",executed_us=d*64000000+10) for d in range(4)]
        self.assertEqual(len(trips(w)),3)
        w["agents"]["npc_b"]=dict(actions=[action(0,"npc_b")])
        w["stock_events"].append(dict(agent_id="npc_b",operation_id="b-pick",executed_us=10))
        self.assertEqual([(x["agent_id"],x["day"]) for x in trips(w)],[("npc_a",1),("npc_b",1),("npc_a",2)])


if __name__=="__main__":unittest.main()
