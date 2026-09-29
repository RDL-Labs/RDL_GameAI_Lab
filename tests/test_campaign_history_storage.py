import copy
import gzip
import json
import unittest
from unittest.mock import patch
from runtime.landmark_return_campaign import ReturnCampaign
from runtime.landmark_day_cycle import DAY_US,phase


def recorded():
    with gzip.open("tests/fixtures/luanti_l15a_landmark_day_cycle.json.gz","rt",encoding="utf8") as stream:
        world=json.load(stream)["runs"][0]["data"]["world"]
    loop=ReturnCampaign(world["run_id"],3)
    return loop,world["deliveries"]


def request(entry,loop):
    p=copy.deepcopy(entry["request"])
    if entry["kind"]=="configure":p["schema"]=loop.schema
    return p


class CampaignHistoryStorageTests(unittest.TestCase):
    def test_night_failure_retry_and_historical_state_isolation(self):
        loop,entries=recorded();tested=False
        for e in entries:
            p=request(e,loop)
            if e["kind"]=="observe" and p["capture_us"]//DAY_US==1 and phase(p["capture_us"])=="night" and not tested:
                a=loop.agents[p["agent_id"]];old=next(reversed(a.decisions.values()))["day_cycle"]
                self.assertEqual(len(old["nights"]),1)
                before=loop.snapshot()
                with patch.object(a,"_stage_sensory_store",side_effect=ValueError("injected staging failure")):
                    with self.assertRaisesRegex(ValueError,"injected staging failure"):loop.observe(p)
                self.assertEqual(loop.snapshot(),before)
                self.assertEqual(loop.observe(p),json.loads(e["response_wire"]))
                current=a.decisions[p["observation_id"]]["day_cycle"]
                self.assertEqual(len(old["nights"]),1);self.assertEqual(len(current["nights"]),2)
                self.assertIs(old["nights"][0],current["nights"][0])
                snapshot=loop.snapshot();again=loop.observe(p)
                self.assertEqual(again["new_observations"],0);self.assertEqual(loop.snapshot(),snapshot)
                tested=True
            else:self.assertEqual(getattr(loop,e["kind"])(p),json.loads(e["response_wire"]))
        self.assertTrue(tested)

    def test_public_snapshot_records_remain_independent(self):
        loop,entries=recorded()
        for e in entries:getattr(loop,e["kind"])(request(e,loop))
        agent=loop.agents["npc_a"]
        ds=[d for d in agent.decisions.values() if d["day_cycle"]["nights"]]
        self.assertGreater(len(ds),3)
        self.assertIs(ds[0]["day_cycle"]["nights"][0],ds[1]["day_cycle"]["nights"][0])
        state=agent.snapshot()
        copies=[d for d in state["decisions"].values() if d["day_cycle"]["nights"]]
        original=copy.deepcopy(ds[0]["day_cycle"]["nights"][0])
        self.assertTrue(original["records"])
        copies[0]["day_cycle"]["nights"][0]["records"].clear()
        copies[0]["day_cycle"]["nights"][0]["status"]="caller mutation"
        self.assertEqual(copies[1]["day_cycle"]["nights"][0],original)
        self.assertEqual(ds[0]["day_cycle"]["nights"][0],original)
        self.assertEqual(ds[1]["day_cycle"]["nights"][0],original)
