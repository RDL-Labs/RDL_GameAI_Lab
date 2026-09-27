import copy
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import unittest

from runtime.exploration import FiniteExploration, SCHEMA, GROUND, CELLS, choose
from runtime.core import ObservationError
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def setup(run="test"):
    loop = FiniteExploration(run)
    config = dict(schema=SCHEMA, run_id=run, world_epoch=1, agent_id="npc_a", clock_id="world-sim-v1")
    loop.configure(config)
    return loop, config


def packet(seq=0, run="test"):
    time = seq*250000 + 20000
    p = dict(run_id=run, world_epoch=1, agent_id="npc_a", clock_id="world-sim-v1",
             observation_id=f"o{seq}", capture_us=time, sample_seq=seq, pose_ref="pose0", body_revision=0,
             ground=dict(model=GROUND, profile="l13a-ground-fixed-v1", coverage="complete",
                         cells=[dict(cell_id=k, color="gray", status="sampled") for k in CELLS]),
             food=dict(coverage="complete", visible=[]))
    p["distant"] = dict(frame_id=f"d{seq}", agent_id="npc_a", sensor_id="eye", channel="vision_distant",
                        profile_id="fixture-distant-enabled", profile_revision=1,
                        sensor_model_revision="sampled-surface-v0.2", sample_seq=seq, clock_id="world-sim-v1",
                        capture_window=dict(kind="instant", start_us=time, end_us=time), sampled_world_tick=seq,
                        observer_frame_ref="pose0", status="SAMPLED", coverage="COMPLETE_WITHIN_PLAN",
                        output_limited=False, payload=dict(features=[]))
    return p


def result(command, status="moved"):
    r = {k:command[k] for k in ("run_id", "world_epoch", "agent_id", "operation_id", "source_id")}
    changed = status in ("moved", "turned", "picked_up")
    r.update(executed_us=command["capture_us"]+20000,
             before_pose_ref=command["pose_ref"], after_pose_ref="pose1" if changed else command["pose_ref"],
             before_revision=command["body_revision"], after_revision=command["body_revision"]+int(changed),
             status=status, forward=1 if status=="moved" else 0, right=0,
             yaw=command["amount"] if status=="turned" else 0, acquired=status=="picked_up")
    return r


class ExplorationTests(unittest.TestCase):
    def test_http_opt_in_and_invalid_input(self):
        from http.server import ThreadingHTTPServer
        from threading import Thread
        from urllib.request import Request, urlopen
        from urllib.error import HTTPError
        from runtime.bridge import BridgeHandler
        server=ThreadingHTTPServer(("127.0.0.1",0),BridgeHandler)
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        url=f"http://127.0.0.1:{server.server_port}/v1/exploration/observe"
        def post(p):
            with urlopen(Request(url,json.dumps(p).encode(),{"Content-Type":"application/json"}),timeout=2) as response:
                return json.load(response)
        try:
            with self.assertRaises(HTTPError) as e:post(packet())
            self.assertEqual(e.exception.code,404)
            e.exception.close()
            server.exploration,_=setup()
            self.assertEqual(post(packet())["new_frames"],1)
            bad=packet(1);bad["destination"]=[24,12]
            before=server.exploration.snapshot()
            with self.assertRaises(HTTPError) as e:post(bad)
            self.assertEqual(e.exception.code,422)
            e.exception.close()
            self.assertEqual(before,server.exploration.snapshot())
        finally:
            server.shutdown();server.server_close();thread.join()

    def test_lifecycle_and_isolated_mode(self):
        loop=FiniteExploration("test")
        for method,value in (("observe",packet()),("result",{}),("finish",{})):
            with self.assertRaisesRegex(ValueError,"not_configured"):getattr(loop,method)(value)
        from runtime.bridge import run
        with self.assertRaisesRegex(ValueError,"isolated"):run(host="0.0.0.0",finite_exploration=True)
        with self.assertRaisesRegex(ValueError,"isolated"):run(finite_exploration=True,resource_use_learning=True)

    def test_atomic_ground_distant_admission(self):
        loop,_ = setup(); p=packet(); before=loop.snapshot()
        p["distant"]["payload"]["world_id"]="hidden"
        with self.assertRaises(ObservationError): loop.observe(p)
        self.assertEqual(before, loop.snapshot())
        r=loop.observe(packet()); self.assertEqual(r["new_frames"],1)
        self.assertEqual(loop.snapshot()["sensory"]["count"],1)

    def test_replay_conflict_and_copy(self):
        loop,_=setup(); p=packet(); r=loop.observe(p)
        again=loop.observe(p);self.assertEqual(again["new_frames"],0)
        self.assertEqual(r["command"],again["command"])
        p["ground"]["cells"][0]["color"]="blue"
        with self.assertRaisesRegex(ValueError,"conflict"):loop.observe(p)
        r["command"]["kind"]="bad"
        self.assertEqual(loop.observe(packet())["command"]["kind"],"move")

    def test_concurrent_replay(self):
        loop,_=setup()
        with ThreadPoolExecutor(4) as pool: replies=list(pool.map(loop.observe,[packet() for _ in range(8)]))
        self.assertEqual(sum(r["new_frames"] for r in replies),1)
        self.assertEqual(len(loop.commands),1)

    def test_local_color_and_partial(self):
        for index,expected in ((1,("move",1)),(3,("turn",90)),(5,("turn",-90)),(7,("turn",90))):
            p=packet();p["ground"]["cells"][index]["color"]="blue"
            self.assertEqual(choose(p)[:2],expected)
        p["ground"]["cells"][0].update(color="unknown",status="unloaded")
        p["ground"]["coverage"]="partial"
        loop,_=setup();r=loop.observe(p)
        self.assertEqual(r["command"]["kind"],"wait")
        self.assertEqual(r["command"]["reason"],"acquisition_incomplete")

    def test_food_observation_changes_action(self):
        for forward,right,distance,kind,amount in ((0,4,4,"turn",90),(0,-4,4,"turn",-90),
                                                  (4,0,4,"move",1),(1,0,1,"pickup",0)):
            p=packet();p["food"]["visible"]=[dict(ref="food",forward=forward,right=right,distance=distance)]
            loop,_=setup();c=loop.observe(p)["command"]
            self.assertEqual((c["kind"],c["amount"]),(kind,amount))
            self.assertEqual(c["target_ref"],"food" if kind=="pickup" else "")

    def test_unobserved_target_and_world_fields_rejected(self):
        for key in ("scenario","world_position","route","food_destination"):
            loop,_=setup();p=packet();p[key]="oracle";before=loop.snapshot()
            with self.assertRaises(ValueError):loop.observe(p)
            self.assertEqual(before,loop.snapshot())
        p=packet();p["food"]["visible"]=[dict(ref="food",distance=13,forward=13,right=0)]
        with self.assertRaises(ValueError):loop.observe(p)

    def test_context_clock_profile_pose(self):
        for key,value in (("run_id","other"),("agent_id","npc_b"),("world_epoch",2),("clock_id","other"),
                          ("sample_seq",True),("capture_us",16000000),("pose_ref","different")):
            loop,_=setup();p=packet();p[key]=value
            with self.assertRaises(ValueError):loop.observe(p)
        p=packet();p["ground"]["profile"]="dynamic"
        with self.assertRaises(ValueError):loop.observe(p)

    def test_ground_missing_not_negative(self):
        for mutate in (lambda p:p["ground"]["cells"].pop(),
                       lambda p:p["ground"]["cells"][0].update(color="unknown"),
                       lambda p:p["ground"].update(coverage="partial")):
            p=packet();mutate(p);loop,_=setup()
            with self.assertRaises(ValueError):loop.observe(p)

    def test_order_capacity_and_replay_after_full(self):
        loop,_=setup()
        for i in range(64):loop.observe(packet(i))
        self.assertEqual(loop.observe(packet())["new_frames"],0)
        with self.assertRaises(ValueError):loop.observe(packet(64))
        p=packet();p["observation_id"]="new-old"
        with self.assertRaises(ValueError):loop.observe(p)
        self.assertEqual(len(loop.commands),64)

    def test_results_measured_and_idempotent(self):
        loop,_=setup();c=loop.observe(packet())["command"];r=result(c)
        self.assertTrue(loop.result(r)["new_result"])
        self.assertFalse(loop.result(r)["new_result"])
        r["forward"]=0
        with self.assertRaisesRegex(ValueError,"conflict"):loop.result(r)
        self.assertEqual(loop.snapshot()["results"][c["operation_id"]]["forward"],1)

    def test_expired_stale_stopped_have_no_effect(self):
        for status in ("expired","stale","stopped"):
            loop,_=setup();c=loop.observe(packet())["command"];r=result(c,status)
            if status=="expired":r["executed_us"]=c["expires_us"]
            if status=="stale":r.update(before_revision=1,after_revision=1,before_pose_ref="other",after_pose_ref="other")
            if status=="stopped":r["executed_us"]=16000000
            self.assertTrue(loop.result(r)["accepted"])
        loop,_=setup();c=loop.observe(packet())["command"];r=result(c)
        r["executed_us"]=c["expires_us"]
        with self.assertRaisesRegex(ValueError,"execution_binding"):loop.result(r)

    def test_fabricated_effects_rejected_atomically(self):
        for key,value in (("forward",0),("right",1),("yaw",90),("acquired",True),("after_revision",0),
                          ("before_pose_ref","wrong"),("source_id","unseen"),("agent_id","npc_b")):
            loop,_=setup();c=loop.observe(packet())["command"];before=loop.snapshot();r=result(c);r[key]=value
            with self.assertRaises(ValueError):loop.result(r)
            self.assertEqual(before,loop.snapshot())

    def test_blocked_turns_instead_of_oracle(self):
        loop,_=setup();c=loop.observe(packet())["command"]
        loop.result(result(c,"blocked"))
        c=loop.observe(packet(1))["command"]
        self.assertEqual((c["kind"],c["amount"]),("turn",90))

    def test_finish_requires_results_and_timeout(self):
        loop,_=setup();c=loop.observe(packet())["command"]
        end=dict(run_id="test",world_epoch=1,agent_id="npc_a",ended_us=16000000,reason="time_limit")
        with self.assertRaisesRegex(ValueError,"unreported"):loop.finish(end)
        loop.result(result(c));self.assertEqual(loop.finish(end),loop.finish(end))
        self.assertEqual(loop.observe(packet())["new_frames"],0)
        with self.assertRaisesRegex(ValueError,"closed"):loop.observe(packet(1))
        loop,_=setup();end["ended_us"]=1
        with self.assertRaisesRegex(ValueError,"early_timeout"):loop.finish(end)

    def test_success_is_pickup_not_visibility(self):
        loop,_=setup();p=packet();p["food"]["visible"]=[dict(ref="food",distance=1,forward=1,right=0)]
        c=loop.observe(p)["command"]
        end=dict(run_id="test",world_epoch=1,agent_id="npc_a",ended_us=50000,reason="acquired")
        loop.result(result(c,"not_found"))
        with self.assertRaisesRegex(ValueError,"acquisition"):loop.finish(end)
        loop,_=setup();c=loop.observe(p)["command"];loop.result(result(c,"picked_up"))
        self.assertTrue(loop.finish(end)["accepted"])

    def test_opaque_names_and_mountains_do_not_choose_route(self):
        a=packet();b=packet(run="another");b["observation_id"]="episode-last"
        b["distant"]["payload"]["features"]=[dict(feature_id="arbitrary",azimuth_interval_deg=[30,35],
             elevation_interval_deg=[0,5],angular_width_band="unknown",angular_height_band="unknown",color_band="muted_red")]
        self.assertEqual(choose(a),choose(b))
        x,_=setup();y,_=setup("another")
        self.assertEqual(x.observe(a)["command"]["kind"],y.observe(b)["command"]["kind"])

    def test_no_canonical_or_history_authority(self):
        from runtime.bridge import EXPERIENCE
        can=GameAIFrozenComparisonSidecar();before=can.snapshot();history=EXPERIENCE.snapshot()
        loop,_=setup();loop.result(result(loop.observe(packet())["command"]))
        self.assertEqual(can.snapshot(),before);self.assertEqual(EXPERIENCE.snapshot(),history)
        self.assertFalse(hasattr(loop,"learn"));self.assertFalse(hasattr(loop,"review"))

    def test_real_replay(self):
        from integrations.luanti.tests.check_exploration import check
        path=Path(__file__).parent/'fixtures'/'luanti_l13a_replay.json'
        data=json.loads(path.read_text(encoding="utf-8"))
        for run in data["runs"]:check(run)


if __name__ == "__main__":unittest.main()
