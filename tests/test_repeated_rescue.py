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
from runtime.repeated_rescue import RepeatedRescueSelector, RepeatedRescueError
from runtime.rescue_experience import RescueExperienceError

ROOT = Path(__file__).resolve().parents[1]
AVAILABLE = ["solo", "joint", "defer"]


def events(run):
    source=json.loads((ROOT/"tests/fixtures/soc0_godot_replay.json").read_text(encoding="utf-8"))["world"]["experiences"]
    for i,e in enumerate(source):
        e["run_id"]=run;e["event_id"]=f"{run}:event:{i}"
    return source


def choose(s,values=None,identity="first",available=None):
    return s.choose(choice_id=identity,events=values or [],available_conditions=available or AVAILABLE)


def complete(s,episode,run):
    s.begin_episode(episode,run);data=events(run)
    first=choose(s)
    if first["selected"]=="solo":
        choose(s,data[:1],"after-failure")
    else:
        data=data[1:]
    return first,s.finish_episode(data,"completed")


class RepeatedRescueTests(unittest.TestCase):
    def test_retention_changes_later_choice_not_first(self):
        for keep,expected in ((True,["solo","joint","joint"]),(False,["solo","solo","solo"])):
            s=RepeatedRescueSelector(retain_previous=keep)
            first=[]
            for episode in ("alpha","beta","gamma"):
                decision,_=complete(s,episode,"world-"+episode);first.append(decision["selected"])
                if not keep:self.assertEqual(decision["accessible_episode_ids"],[episode])
            self.assertEqual(first,expected)

    def test_episode_labels_do_not_select_joint_without_experience(self):
        for name in ("Episode3","99","last","alpha"):
            s=RepeatedRescueSelector();s.begin_episode(name,"run-"+name)
            self.assertEqual(choose(s)["selected"],"solo")

    def test_success_support_counts_deliveries_once_per_episode(self):
        s=RepeatedRescueSelector();complete(s,"one","r1");complete(s,"two","r2")
        s.begin_episode("three","r3");d=choose(s)
        joint=next(c for c in d["candidates"] if c["condition"]=="joint")
        self.assertEqual(joint["success_episode_count"],2)
        self.assertEqual(len(joint["success_evidence"]),2)
        self.assertEqual({e["result"] for e in d["source_events"]},{"carry_not_established","carry_established","delivered"})
        self.assertNotIn("r3",{e["run_id"] for e in d["source_events"]})

    def test_joint_unavailable_never_forced_by_memory(self):
        s=RepeatedRescueSelector();complete(s,"one","r1");s.begin_episode("two","r2")
        self.assertEqual(choose(s,available=["solo","defer"])["selected"],"solo")
        self.assertEqual(choose(s,events("r2")[:1],"failed",["solo","defer"])["selected"],"defer")
        s.finish_episode(events("r2")[:1],"deferred")

    def test_both_conditions_fail_then_defer(self):
        s=RepeatedRescueSelector();s.begin_episode("one","r1");e=events("r1")
        choose(s);choose(s,e[:1],"failed")
        e[1]["result"]="carry_not_established"
        e[1]["world_consequence"]={"target_moved":False,"carry_established":False}
        self.assertEqual(choose(s,e[:2],"both-failed")["selected"],"defer")
        s.finish_episode(e[:2],"deferred")
        s.begin_episode("two","r2")
        self.assertEqual(choose(s)["selected"],"solo")

    def test_attachment_only_is_not_delivery_support(self):
        s=RepeatedRescueSelector();s.begin_episode("one","r1");e=events("r1")
        choose(s,available=["joint","defer"])
        s.finish_episode(e[1:2],"incomplete")
        s.begin_episode("two","r2");d=choose(s)
        self.assertEqual(d["selected"],"solo")
        self.assertTrue(all(c["success_episode_count"]==0 for c in d["candidates"][:2]))

    def test_replay_is_stable_and_conflict_is_atomic(self):
        s=RepeatedRescueSelector();s.begin_episode("one","r1")
        d=choose(s);before=s.snapshot();self.assertEqual(choose(s),d);self.assertEqual(s.snapshot(),before)
        with self.assertRaisesRegex(RepeatedRescueError,"choice_conflict"):
            choose(s,identity="first",available=["joint","defer"])
        self.assertEqual(s.snapshot(),before)
        d["candidates"].clear();self.assertEqual(s.snapshot(),before)

    def test_rejections_do_not_publish_partial_events(self):
        edits=[lambda e:e[0].update(run_id="foreign"),lambda e:e[0].update(agent_id="npc_c"),
               lambda e:e[0].update(hidden_capacity=2),
               lambda e:e[0].update(participants=["npc_a","npc_d"],attempt_condition="joint"),lambda e:e.append(e[0]),
               lambda e:e[0].update(result="delivered",action="deliver")]
        for edit in edits:
            s=RepeatedRescueSelector();s.begin_episode("one","r1");choose(s);before=s.snapshot();e=events("r1")[:1];edit(e)
            with self.assertRaises((RepeatedRescueError,RescueExperienceError)):choose(s,e,"bad")
            self.assertEqual(s.snapshot(),before)

    def test_delivery_only_and_unselected_attempt_rejected(self):
        s=RepeatedRescueSelector();s.begin_episode("one","r1");choose(s)
        before=s.snapshot()
        for data in (events("r1")[2:],events("r1")[1:]):
            with self.assertRaises(RepeatedRescueError):s.finish_episode(data,"completed")
            self.assertEqual(s.snapshot(),before)
        choose(s,identity="newer",available=["defer"])
        before=s.snapshot()
        with self.assertRaisesRegex(RepeatedRescueError,"attempt_without_selected_condition"):
            s.finish_episode(events("r1"),"completed")
        self.assertEqual(s.snapshot(),before)

    def test_prefix_and_old_event_reuse_rejected(self):
        s=RepeatedRescueSelector();s.begin_episode("one","r1");choose(s);choose(s,events("r1")[:1],"failed")
        before=s.snapshot()
        with self.assertRaisesRegex(RepeatedRescueError,"prefix"):choose(s,[],"drop")
        self.assertEqual(s.snapshot(),before)
        s.finish_episode(events("r1"),"completed");s.begin_episode("two","r2");choose(s)
        e=events("r2")[1:];e[0]["event_id"]="r1:event:1"
        with self.assertRaisesRegex(RepeatedRescueError,"event_reused"):s.finish_episode(e,"completed")

    def test_finite_budgets_and_active_episode_guard(self):
        s=RepeatedRescueSelector();s.begin_episode("one","r1")
        with self.assertRaises(RepeatedRescueError):s.begin_episode("two","r2")
        for i in range(3):choose(s,identity=str(i),available=["defer"])
        with self.assertRaisesRegex(RepeatedRescueError,"choice_budget"):choose(s,identity="over")
        s.finish_episode([],"deferred")
        with self.assertRaisesRegex(RepeatedRescueError,"identity_reused"):s.begin_episode("one","r2")
        complete(s,"two","r2");complete(s,"three","r3")
        with self.assertRaisesRegex(RepeatedRescueError,"episode_budget"):s.begin_episode("four","r4")

    def test_saved_real_world_choices_replay_from_prior_events_only(self):
        data=json.loads((ROOT/"tests/fixtures/soc1_godot_replay.json").read_text(encoding="utf-8"))["experiment"]
        for arm in ("retained","reset"):
            s=RepeatedRescueSelector(retain_previous=arm=="retained")
            saved=data[arm+"_selector"]
            for ep,world in zip(saved["episodes"],data[arm]):
                s.begin_episode(ep["episode_id"],ep["world_run_id"])
                for choice,observed in zip(ep["choices"],world["choices"]):
                    self.assertEqual(s.choose(**choice["request"]),choice["result"])
                    self.assertEqual(choice["result"],observed)
                s.finish_episode(ep["events"],ep["status"])
            self.assertEqual(s.snapshot(),saved)

    @unittest.skipUnless(os.environ.get("GODOT_BIN"),"set GODOT_BIN for SOC-1 real World/HTTP")
    def test_real_three_episode_retention_control(self):
        captured={}
        output_dir=ROOT/"integrations/luanti/output"
        output_dir.mkdir(parents=True,exist_ok=True)
        for keep in (True,False):
            selector=RepeatedRescueSelector(retain_previous=keep)
            arm="retained" if keep else "reset"
            captured[arm]=[]
            for label in ("alpha","beta","gamma"):
                run=f"soc1-{arm}-{label}"
                selector.begin_episode(label,run)
                class Handler(bridge.BridgeHandler):
                    def do_POST(self):
                        if self.path!="/soc1/choose":return super().do_POST()
                        try:
                            payload=json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                            self._send_json(200,selector.choose(**payload))
                        except (ValueError,TypeError) as exc:self._send_json(400,{"error":str(exc)})
                class RecordingRescue(RescueTrajectoryPolicy):
                    def __init__(self):super().__init__();self.packets=[]
                    def decide(self,packet):self.packets.append(copy.deepcopy(packet));return super().decide(packet)
                rescue=RecordingRescue();canonical=GameAIFrozenComparisonSidecar()
                with patch.object(bridge,"EXPERIENCE",InteractionHistory()),patch.object(bridge,"CANONICAL_SIDECAR",canonical):
                    server=ThreadingHTTPServer(("127.0.0.1",8765),Handler)
                    server.history_policy=None;server.rescue_policy=rescue
                    thread=threading.Thread(target=server.serve_forever);thread.start()
                    path=output_dir/(run+".json")
                    try:
                        process=subprocess.run([os.environ["GODOT_BIN"],"--headless","--path",str(ROOT/"godot/rdl-game-ai-workbench"),
                            "--script","res://tests/repeated_rescue_http_check.gd"],capture_output=True,text=True,timeout=60,
                            env={**os.environ,"SOC1_WORLD_RUN":run,"SOC1_EVIDENCE_PATH":str(path)},
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0)
                        output=process.stdout+process.stderr;(output_dir/(run+".log")).write_text(output,encoding="utf-8")
                        self.assertEqual(process.returncode,0,output);self.assertIn("SOC-1 EPISODE PASS",output)
                        world=json.loads(path.read_text(encoding="utf-8"))
                        self.assertEqual(world["metrics"]["status"],"completed")
                        self.assertEqual(world["recovery_stages"],["stabilizing","mobilizing","recovering","recovered"])
                        self.assertEqual(world["initial"]["carry_attempts"],0);self.assertEqual(world["initial"]["experiences"],0)
                        self.assertEqual(rescue.snapshot()["trajectories"],{})
                        self.assertEqual(canonical.snapshot()["T1_materials"]["count"],0)
                        for surface in (world["choices"],world["experiences"],rescue.packets):
                            text=json.dumps(surface)
                            for forbidden in ("carry_load","carry_capabilities","combined_capacity","requires_helper","required_carriers"):
                                self.assertNotIn(forbidden,text)
                        finished=selector.finish_episode(world["experiences"],world["metrics"]["status"])
                        self.assertEqual(world["choices"],[c["result"] for c in finished["choices"]])
                        for check,e in zip(world["world_checks"],[e for e in world["experiences"] if e["action"]=="rescue"]):
                            self.assertEqual(check["active"],e["participants"])
                        captured[arm].append(world)
                    finally:
                        server.shutdown();thread.join();server.server_close()
            captured[arm+"_selector"]=selector.snapshot()
        self.assertEqual([e["metrics"]["first_condition"] for e in captured["retained"]],["solo","joint","joint"])
        self.assertEqual([e["metrics"]["first_condition"] for e in captured["reset"]],["solo","solo","solo"])
        self.assertEqual([e["metrics"]["solo_attempts"] for e in captured["retained"]],[1,0,0])
        self.assertEqual([e["metrics"]["solo_attempts"] for e in captured["reset"]],[1,1,1])
        self.assertTrue(all(e["initial"]==captured["retained"][0]["initial"] for arm in ("retained","reset") for e in captured[arm]))
        self.assertEqual([e["metrics"]["actions_to_delivery"] for e in captured["retained"]],[12,11,11])
        self.assertEqual([e["metrics"]["actions_to_delivery"] for e in captured["reset"]],[12,12,12])
        (output_dir/"soc1-repeated-world.json").write_text(json.dumps(captured,ensure_ascii=False,indent=2),encoding="utf-8")
        print("SOC-1 RETAINED: solo/joint/joint; RESET: solo/solo/solo; delivery actions 12/11/11 vs 12/12/12")
