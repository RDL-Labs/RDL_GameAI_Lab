"""L13A real-World measurements plus exact accepted-wire replay."""
import json
from math import dist, isclose
from pathlib import Path
import sys

from runtime.exploration import FiniteExploration, LIMIT_US


def check(data, *, replay_loop=None, fixed_policy=True):
    w=data["world"];s=data["runtime"]["exploration"]
    assert not w.get("failure"),w.get("failure")
    assert w["lua_checks"]==24,w["lua_checks"]
    assert data["runtime"]["canonical"]==data["initial"]["canonical"]
    assert data["runtime"]["history"]==data["initial"]["history"]
    assert fixed_policy or replay_loop is not None, "learned replay requires frozen series context"
    loop=replay_loop or FiniteExploration(w["run_id"])
    for d in w["deliveries"]:
        actual=getattr(loop,d["kind"])(d["request"])
        assert actual==json.loads(d["response_wire"]),(d["kind"],actual)
    assert loop.snapshot()==s,"accepted replay differs"
    observations=w["observations"];actions=w["actions"]
    assert 1<=len(observations)<=64
    assert len(s["observations"])==s["sensory"]["count"]==len(observations)
    assert len(actions)==len(s["results"])==len(s["commands"])==w["controller"]["count"]
    assert not observations[0]["packet"]["food"]["visible"],"Food initially known"
    assert len({o["packet"]["sample_seq"] for o in observations})==len(observations)
    assert all(abs(o["daytime"]-.5)<.001 for o in observations)
    assert any(o["packet"]["distant"]["payload"]["features"] for o in observations),"no real distant mountain observation"
    assert len(w["mountains"])==3
    assert all(m["node_name"]==m["readback"] for m in w["mountains"])
    assert w["guards"]["duplicate_operation"]
    assert w["max_pending"]<=8 and w["finished_us"]<=25000000
    distance=0;rotation=0;effects=0
    for a in actions:
        r=a["result"];c=a["command"];before=a["before"];after=a["after"]
        dp=dist([before["position"][k] for k in "xyz"],[after["position"][k] for k in "xyz"])
        distance+=dp;rotation+=abs(r["yaw"])
        assert dp<=1.00001 and abs(r["yaw"])<=90.01
        assert abs(after["position"]["x"])<=32.00001 and abs(after["position"]["z"])<=32.00001
        assert r["before_revision"]==before["revision"] and r["after_revision"]==after["revision"]
        if r["status"] in ("expired","stale","stopped","blocked","waited","not_found"):
            assert dp==0 and r["yaw"]==0 and not r["acquired"]
        else:
            effects+=1
            assert r["executed_us"]<c["expires_us"]
        if r["acquired"]:
            source=s["observations"][c["source_id"]]
            assert source["food"]["visible"][0]["ref"]==c["target_ref"]
            assert dist([before["position"][k] for k in "xyz"],[w["food_initial"][k] for k in "xyz"])<=1.25
    assert isclose(distance,w["controller"]["distance"],abs_tol=1e-5) and distance<=64.00001
    assert isclose(rotation,w["controller"]["rotation"],abs_tol=1e-5) and rotation<=5760.01
    assert effects==w["controller"]["effects"]
    acquired=s["ending"]["reason"]=="acquired"
    assert sum(r["acquired"] for r in s["results"].values())==int(acquired)==w.get("pickups",0)
    positive=w["scenario"] in ("straight","right","left","rotated","faults")
    if fixed_policy: assert acquired==positive,(w["scenario"],s["ending"])
    if acquired:
        assert w["first_food_us"]<=w["acquired_us"]<LIMIT_US
    else:
        assert s["ending"]["reason"]=="time_limit" and s["ending"]["ended_us"]>=LIMIT_US
        assert w.get("acquired_us") is None
    if w["scenario"]=="no_strip":
        assert not any(c["color"]=="blue" for o in observations for c in o["packet"]["ground"]["cells"])
    if w["scenario"]=="no_food":assert all(not o["packet"]["food"]["visible"] for o in observations)
    if w["scenario"]=="partial" and fixed_policy:
        assert all(o["packet"]["ground"]["coverage"]=="partial" for o in observations)
        assert distance==rotation==0
    if w["scenario"]=="blocked" and fixed_policy:assert any(a["result"]["status"]=="blocked" for a in actions)
    if w["scenario"]=="faults":
        assert w["lost_response"] and w["loss_recovered"] and w["guards"]["old_callback"]
        delayed=[d for d in w["deliveries"] if d["kind"]=="observe" and d["request"]["sample_seq"]==3][0]
        assert delayed["received_us"]-delayed["arrived_us"]>=750000
        assert any(delayed["arrived_us"]<o["packet"]["capture_us"]<delayed["received_us"] for o in observations)
        assert any(a["result"]["status"]=="expired" for a in actions)
        assert any(json.loads(d["response_wire"]).get("new_frames")==0 for d in w["deliveries"])
    return dict(scenario=w["scenario"],observations=len(observations),result=s["ending"]["reason"],
                distance=round(distance,3),actions=len(actions),first_food_us=w.get("first_food_us"),acquired_us=w.get("acquired_us"))


if __name__=="__main__":
    data=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
    print("L13A PASS " + json.dumps(check(data)))
