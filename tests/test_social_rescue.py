import copy
import json
import os
from pathlib import Path
import subprocess
import threading
import unittest
from http.server import ThreadingHTTPServer
from unittest.mock import patch
from runtime import bridge
from runtime.experience import InteractionHistory
from runtime.rescue_policy import RescueTrajectoryPolicy
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from runtime.rescue_experience import RescueExperienceStore, RescueExperienceError

ROOT=Path(__file__).resolve().parents[1]


def event():
    return {"schema":"soc0-rescue-experience-v1","run_id":"r","event_id":"e","agent_id":"a",
            "source_observation_id":"before","subsequent_observation_id":"after","tick":0,"action":"rescue",
            "target_id":"b","participants":["a"],"attempt_condition":"solo","result":"carry_not_established",
            "world_consequence":{"target_moved":False,"carry_established":False},
            "body_consequence":{"actor_incapacitated":False,"target_incapacitated":True,"target_recovery_stage":"none"},
            "authority":"bounded-rescue-experience-only; not-social-relation-NERV-T1-or-action"}


class SocialRescueTests(unittest.TestCase):
    def test_replay_conflict_capacity_and_alias(self):
        s=RescueExperienceStore("r",1);e=event();one=s.record(e)
        self.assertEqual(s.record(e),one)
        e["tick"]=1
        with self.assertRaisesRegex(RescueExperienceError,"event_conflict"):s.record(e)
        e["event_id"]="two"
        with self.assertRaisesRegex(RescueExperienceError,"capacity"):s.record(e)
        one["event"].clear();self.assertEqual(len(s.snapshot()["records"]),1)
        self.assertTrue(s.snapshot()["records"][0]["event"])

    def test_hidden_and_inconsistent_evidence_rejected(self):
        for mutate in (lambda e:e.update(hidden_carry_load=2),
                       lambda e:e["world_consequence"].update(combined_capacity=2),
                       lambda e:e.update(participants=["a","a"]),
                       lambda e:e["world_consequence"].update(target_moved=True),
                       lambda e:e.update(run_id="other")):
            e=event();mutate(e);s=RescueExperienceStore("r")
            with self.assertRaises(RescueExperienceError):s.record(e)
            self.assertEqual(s.snapshot()["records"],[])

    def test_saved_world_replay_preserves_distinct_experiences(self):
        data=json.loads((ROOT/"tests/fixtures/soc0_godot_replay.json").read_text(encoding="utf-8"))["world"]
        store=RescueExperienceStore("soc0-real-world")
        for e in data["experiences"]:store.record(e)
        before=store.snapshot()
        for e in data["experiences"]:store.record(e)
        self.assertEqual(store.snapshot(),before)
        self.assertEqual([r["event"]["participants"] for r in before["records"]],[["npc_a"],["npc_a","npc_c"],["npc_a","npc_c"]])
        self.assertEqual(data["world_checks"][0]["target_before"],data["world_checks"][0]["target_after"])
        self.assertEqual(data["recovery_stages"][-1],"recovered")

    @unittest.skipUnless(os.environ.get("GODOT_BIN"),"set GODOT_BIN for SOC-0 real World/HTTP")
    def test_real_world_solo_joint_and_recovery(self):
        outpath=ROOT/"integrations/luanti/output/soc0-world.json"
        class RecordingRescue(RescueTrajectoryPolicy):
            def __init__(self):
                super().__init__();self.packets=[]
            def decide(self,packet):
                self.packets.append(copy.deepcopy(packet))
                return super().decide(packet)
        rescue=RecordingRescue();canonical=GameAIFrozenComparisonSidecar()
        with patch.object(bridge,"EXPERIENCE",InteractionHistory()),patch.object(bridge,"CANONICAL_SIDECAR",canonical):
            server=ThreadingHTTPServer(("127.0.0.1",8765),bridge.BridgeHandler)
            server.history_policy=None;server.rescue_policy=rescue
            thread=threading.Thread(target=server.serve_forever);thread.start()
            try:
                result=subprocess.run([os.environ["GODOT_BIN"],"--headless","--path",str(ROOT/"godot/rdl-game-ai-workbench"),
                    "--script","res://tests/heavy_rescue_http_check.gd"],capture_output=True,text=True,timeout=60,
                    env={**os.environ,"SOC0_EVIDENCE_PATH":str(outpath)},creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
                output=result.stdout+result.stderr
                (outpath.parent/"soc0-godot.log").write_text(output,encoding="utf-8")
                self.assertEqual(result.returncode,0,output)
                self.assertIn("SOC-0 Heavy Rescue PASS",output)
                evidence=json.loads(outpath.read_text(encoding="utf-8"))
                self.assertFalse(evidence["world_checks"][0]["target_moved"])
                self.assertEqual(evidence["recovery_stages"],["stabilizing","mobilizing","recovering","recovered"])
                s=RescueExperienceStore("soc0-real-world")
                for e in evidence["experiences"]:s.record(e)
                records=s.snapshot()["records"]
                self.assertEqual([r["event"]["result"] for r in records],["carry_not_established","carry_established","delivered"])
                self.assertEqual(len({r["record_id"] for r in records}),3)
                for surface in (evidence["experiences"],evidence["observations"],rescue.packets):
                    text=json.dumps(surface)
                    for forbidden in ("carry_load","carry_capabilities","combined_capacity","required_carriers","requires_helper","correct_helper"):
                        self.assertNotIn(forbidden,text)
                self.assertEqual(rescue.snapshot()["trajectories"],{})
                self.assertEqual(canonical.snapshot()["T1_materials"]["count"],0)
                print(output.strip())
            finally:
                server.shutdown();thread.join();server.server_close()
