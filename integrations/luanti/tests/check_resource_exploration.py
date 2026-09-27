"""L14A: stock/body continuity, source-attributed teaching, real rays and wire replay."""
from collections import Counter
import gzip
import json
from math import dist, sin, cos, radians, isclose
from pathlib import Path
import sys

from runtime.resource_exploration import ResourceExploration, PERIOD_US
from .check_landmark_exploration import round_node


def xyz(v): return [v[k] for k in "xyz"]


def check_rays(o):
    colors=dict(grass="green",dirt="brown",stone="gray",trunk="brown",leaves="green",water="blue",
                rock_gray="gray",rock_red="red",patch_brown="brown",patch_gray="gray")
    fs,previous,partial=[], -2, False
    assert len(o["landmark_rays"])==13
    b=o["body"]
    for i,r in enumerate(o["landmark_rays"]):
        assert r["angle"]==-90+15*i and 1<=r["samples"]<=192
        if r["status"] in ("unloaded","unclassified"): partial=True
        if r["status"]!="sampled":continue
        h=r["hit"];assert isclose(h["distance"],r["samples"]*.125)
        theta=b["yaw"]-radians(r["angle"])
        assert h["position"]==dict(x=round_node(b["position"]["x"]-sin(theta)*h["distance"]),
            y=round_node(b["position"]["y"]+.5),z=round_node(b["position"]["z"]+cos(theta)*h["distance"]))
        color=colors[h["node"].removeprefix("rdl_bridge:exploration_")]
        band="near" if h["distance"]<=3 else ("mid" if h["distance"]<=12 else "far")
        lo,hi=max(-90,r["angle"]-7.5),min(90,r["angle"]+7.5)
        if previous==i-1 and fs and fs[-1]["color"]==color and fs[-1]["range_band"]==band:
            fs[-1]["azimuth"][1]=hi
        else:fs.append(dict(ref=f"patch{len(fs)}",color=color,azimuth=[lo,hi],range_band=band))
        previous=i
    assert o["packet"]["landmarks"]["features"]==fs
    assert o["packet"]["landmarks"]["coverage"]==("partial" if partial else "complete")


def check(data):
    w,s=data["world"],data["runtime"]["exploration"]
    assert not w.get("failure"),w.get("failure")
    assert (w["lua_checks"],w["natural_checks"],w["landmark_checks"],w["resource_checks"])==(24,18,10,14)
    assert data["runtime"]["canonical"]==data["initial"]["canonical"]
    assert data["runtime"]["history"]==data["initial"]["history"]
    loop=ResourceExploration(w["run_id"],s["periods"],s["seed"])
    for d in w["deliveries"]:
        assert getattr(loop,d["kind"])(d["request"])==json.loads(d["response_wire"]),d["kind"]
    assert loop.snapshot()==s,"wire replay mismatch"
    assert s["ending"]["reason"]=="time_limit" and w["finished_us"]<=loop.deadline_us
    assert len(w["observations"])==len(s["observations"])==s["sensory"]["count"]==loop.capacity
    assert len(w["actions"])==len(s["results"])==w["controller"]["count"]==loop.capacity
    assert [o["packet"]["sample_seq"] for o in w["observations"]]==list(range(loop.capacity))
    assert len(w["periods"])==s["periods"] and w["max_pending"]<=8
    assert {(p["x"],p["y"],p["z"]) for p in w["forceloaded"]}=={
        (x,y,z) for x in range(-64,49,16) for y in range(-16,17,16) for z in range(-64,49,16)}
    assert s["authority"]=="initial-observed-control; learning-not-connected"
    assert all(d["model_ref"] is None for d in s["decisions"].values())
    ta=w["teaching_audit"]
    assert ta["line_of_sight"] and ta["coverage"]=="complete" and ta["distance"]<=12
    assert ta["sample_texture"]=="rdl_l14_acorn.png" and s["teaching"]==w["config"]["teaching"]
    initial={p["ref"]:p for p in w["stock_initial"]}
    assert len(initial)==(2 if w["control"] else 8) and all(p["initial"]==p["remaining"]==2 and p["present"] for p in initial.values())
    assert len(w["resource_trees"])==(2 if w["control"] else 12)
    assert all(t["readback"]=="rdl_bridge:exploration_patch_"+t["color"] for t in w["resource_trees"])
    acquisitions=[];distance=0.;rotation=0.;last=w["initial_body"]
    for a in w["actions"]:
        c,r,b,after=a["command"],a["result"],a["before"],a["after"]
        assert b==last,"body restored or changed outside recorded action"
        last=after
        dp=dist(xyz(b["position"]),xyz(after["position"]))
        distance+=dp;rotation+=abs(r["yaw"])
        assert dp<=2**.5+.00001 and abs(r["yaw"])<=90.01
        assert isclose(r["up"],after["position"]["y"]-b["position"]["y"],abs_tol=1e-5)
        assert r["before_revision"]==b["revision"] and r["after_revision"]==after["revision"]
        if r["status"] in ("moved","turned","picked_up"):
            assert r["executed_us"]<c["expires_us"]<= (c["capture_us"]//PERIOD_US+1)*PERIOD_US
        else:assert dp==0 and r["yaw"]==0 and not r["acquired"]
        if r["acquired"]:
            assert dist(xyz(b["position"]),xyz(initial[c["target_ref"]]["position"]))<=1.25
            acquisitions.append(dict(operation_id=c["operation_id"],target_ref=c["target_ref"],acquired_us=r["executed_us"]))
    assert last==w["final_body"] and acquisitions==s["inventory"]==(w["inventory"] or [])
    assert isclose(distance,w["controller"]["distance"],abs_tol=1e-4)
    assert isclose(rotation,w["controller"]["rotation"],abs_tol=1e-4)
    total=Counter(a["target_ref"] for a in acquisitions)
    assert sum(total.values())==w.get("pickups",0) and all(n<=2 for n in total.values())
    for p in w["final_stock"]:
        assert p["remaining"]==2-total[p["ref"]] and p["present"]==(p["remaining"]>0)
    for period in w["periods"]:
        o=w["observations"][period["period"]*64]
        assert period["body"]==o["body"] and period["capture_us"]==o["packet"]["capture_us"]
        prior=Counter(a["target_ref"] for a in acquisitions if a["acquired_us"]<=period["capture_us"])
        assert period["inventory_count"]==sum(prior.values())
        assert all(p["remaining"]==2-prior[p["ref"]] for p in period["stock"])
    for o in w["observations"]:
        p,b=o["packet"],o["body"];assert abs(o["daytime"]-.5)<.001
        check_rays(o)
        prior=Counter(a["target_ref"] for a in acquisitions if a["acquired_us"]<=p["capture_us"])
        audit=o.get("food_visibility") or []
        assert {a["ref"] for a in audit}=={ref for ref in initial if prior[ref]<2}
        visible=[];partial=False
        for a in audit:
            pos=initial[a["ref"]]["position"];d=dist(xyz(pos),xyz(b["position"]))
            assert isclose(a["distance"],d,abs_tol=1e-4) and a["in_range"]==(d<=12)
            partial |= a["coverage"]!="complete"
            if a["in_range"] and a["line_of_sight"]:
                dx,dy,dz=[pos[k]-b["position"][k] for k in "xyz"];yaw=b["yaw"]
                visible.append(dict(ref=a["ref"],distance=d,forward=-sin(yaw)*dx+cos(yaw)*dz,
                                    right=cos(yaw)*dx+sin(yaw)*dz,up=dy,appearance="brown_capped_ovoid"))
        visible.sort(key=lambda f:(f["distance"],f["ref"]))
        partial |= len(visible)>5
        assert p["food"]["coverage"]==("partial" if partial else "complete")
        assert len(p["food"]["visible"])==min(5,len(visible))
        for item,expected in zip(p["food"]["visible"],visible[:5]):
            assert item["ref"]==expected["ref"] and item["appearance"]==expected["appearance"]
            assert all(isclose(item[k],expected[k],abs_tol=1e-4) for k in ("distance","forward","right","up"))
    if w["faults"]:
        assert w["lost_response"] and w["loss_recovered"] and w["guards"]["old_callback"]
        assert any(json.loads(d["response_wire"]).get("new_frames")==0 for d in w["deliveries"])
        assert any(r["status"]=="expired" for r in s["results"].values())
    if w["control"]:
        assert total and max(total.values())==2,"positive depletion control did not deplete"
        last_pickup=max(a["acquired_us"] for a in acquisitions)
        assert any(a["result"]["executed_us"]>last_pickup and
                   a["command"]["reason"].startswith(("landmark_","neighborhood_")) for a in w["actions"]),"no reexploration"
    bins=[]
    for start in range(0,s["periods"],10):
        lo,hi=start*PERIOD_US,min(start+10,s["periods"])*PERIOD_US
        actions=[a for a in w["actions"] if lo<=a["command"]["capture_us"]<hi]
        pickups=sum(a["result"]["acquired"] for a in actions)
        length=sum(dist(xyz(a["before"]["position"]),xyz(a["after"]["position"])) for a in actions)
        bins.append(dict(periods=[start+1,min(start+10,s["periods"])],pickups=pickups,distance=round(length,3),
                         actions=len(actions),actions_per_pickup=len(actions)/pickups if pickups else None))
    return dict(scenario=w["scenario"],control=w["control"],periods=s["periods"],observations=len(w["observations"]),
        pickups=len(acquisitions),harvested_patches=len(total),depleted_patches=sum(v==2 for v in total.values()),
        remaining=sum(p["remaining"] for p in w["final_stock"]),distance=round(distance,3),bins=bins,
        learned_feature_relation=False)


if __name__=="__main__":
    path=Path(sys.argv[1]);raw=path.read_bytes()
    a=json.loads(gzip.decompress(raw) if path.suffix==".gz" else raw.decode("utf-8-sig"))
    print(json.dumps([check(r["data"]) for r in a["runs"]],ensure_ascii=False,indent=2))
