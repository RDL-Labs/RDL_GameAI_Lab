"""L14B wire replay, shared stock conservation and agent-specific authority."""
from collections import Counter
import json
from math import dist, isclose, sin, cos, isfinite

from runtime.multi_resource_exploration import MultiResourceExploration, AGENTS
from .check_resource_exploration import check_rays, xyz


def computed_float_path(path):
    """Only derived diagnostics, never acquired evidence or control decisions."""
    parts=path.split('/')
    if parts[0]=='$history':
        return 'local_motion' in parts or 'world_audit' in parts
    if len(parts)<7 or parts[1]!='agents' or parts[3]!='decisions':
        return False
    tail=parts[5:]
    if tail[:3]==['rest','recurrence','local_motion']:
        return True
    if tail[0] not in ('movement_terrain','steering','lateral','tie_break'):
        return False
    if any(k in tail for k in ('evidence','context','ground')):
        return False
    return tail[-1] in ('forward_gap','minimum_height','total','physical','food','obstacle',
                        'distance','clearance','value','normalized','raw','obstacle_sum',
                        'observed_terrain_total','final_total')


def first_difference(actual, expected, path='$'):
    """Exact data/commands; 1e-12 roundoff allowance for computed float diagnostics.

    Windows and Linux libm may differ in the last bit of trig/power results.
    Discrete outcomes, thresholds, minima directions and all source inputs stay exact.
    """
    if actual == expected:
        return None
    if (type(actual) is float and type(expected) is float and computed_float_path(path)
            and isfinite(actual) and isfinite(expected)
            and isclose(actual,expected,rel_tol=1e-12,abs_tol=1e-12)):
        return None
    if isinstance(actual, dict) and isinstance(expected, dict) and actual.keys() == expected.keys():
        for key in actual:
            difference = first_difference(actual[key], expected[key], path+'/'+str(key))
            if difference:
                return difference
        return None
    if isinstance(actual, list) and isinstance(expected, list) and len(actual) == len(expected):
        for index, (a, e) in enumerate(zip(actual, expected)):
            difference = first_difference(a, e, path+'/'+str(index))
            if difference:
                return difference
        return None
    return f'{path}: actual={repr(actual)[:180]} expected={repr(expected)[:180]}'


def check(data, loop_type=MultiResourceExploration):
    w,s=data["world"],data["runtime"]["exploration"]
    assert not w.get("failure"),w.get("failure")
    period_us=s.get("period_us",16_000_000)
    assert s["schema"] == loop_type.schema
    loop=loop_type(w["run_id"],s["periods"],s["seed"],s["assignment"])
    for d in w["deliveries"]:
        assert getattr(loop,d["kind"])(d["request"])==json.loads(d["response_wire"])
    difference=first_difference(loop.snapshot(),s)
    assert difference is None, "wire replay differs: "+str(difference)
    assert set(s["agents"])==set(AGENTS)==set(w["agents"])
    stock={p["ref"]:12 for p in w["stock_initial"]}
    assert len(stock)==(2 if w["control"] else 8)
    initial={p["ref"]:p for p in w["stock_initial"]}
    assert all(p["initial"]==p["remaining"]==12 and p["present"] for p in initial.values())
    assert len(w["forceloaded"])==192 and len(w["periods"])==s["periods"]
    assert w["finished_us"]<=s["periods"]*period_us+9_000_000
    history=[dict(stock)]
    for e in w["stock_events"] or []:
        assert {p["ref"]:p["remaining"] for p in e["before"]}==stock
        stock[e["target_ref"]]-=1;assert stock[e["target_ref"]]>=0
        assert {p["ref"]:p["remaining"] for p in e["after"]}==stock
        history.append(dict(stock))
    assert {p["ref"]:p["remaining"] for p in w["final_stock"]}==stock
    assert all(p["present"]==(p["remaining"]>0) for p in w["final_stock"])
    events={e["operation_id"]:e for e in w["stock_events"] or []}
    assert len(events)==len(w["stock_events"] or [])
    summaries={}
    all_operations=set()
    for agent in AGENTS:
        a,t=w["agents"][agent],s["agents"][agent]
        assert len(a["observations"])==len(a["actions"])==len(t["observations"])==len(t["results"])==s["periods"]*(period_us//250000)
        assert a["max_pending"]<=8 and t["ending"]["reason"]=="time_limit"
        assert t["sensory"]["count"]==s["periods"]*(period_us//250000)
        assert not (all_operations & set(t["results"]));all_operations.update(t["results"])
        last=a["initial_body"];inventory=[];distance=0
        for action in a["actions"]:
            c,r=action["command"],action["result"]
            assert c["agent_id"]==r["agent_id"]==agent
            assert action["before"]==last;last=action["after"]
            step=dist(xyz(action["before"]["position"]),xyz(last["position"]))
            distance+=step
            assert step<=2**.5+.00001 and abs(r["yaw"])<=90.01
            assert r["before_revision"]==action["before"]["revision"] and r["after_revision"]==last["revision"]
            if r["status"] in ("picked_up","moved","turned"):
                assert r["executed_us"]<c["expires_us"]<=(c["capture_us"]//period_us+1)*period_us
            else:assert step==0 and r["yaw"]==0 and not r["acquired"]
            if r["acquired"]:
                assert events[c["operation_id"]]["agent_id"]==agent
                assert dist(xyz(action["before"]["position"]),xyz(initial[c["target_ref"]]["position"]))<=1.25
                inventory.append(dict(operation_id=c["operation_id"],target_ref=c["target_ref"],acquired_us=r["executed_us"]))
        assert last==a["final_body"] and inventory==(a["inventory"] or [])==t["inventory"]
        assert isclose(distance,a["controller"]["distance"],abs_tol=1e-4)
        for i,o in enumerate(a["observations"]):
            p=o["packet"];assert p["sample_seq"]==i and p["agent_id"]==p["distant"]["agent_id"]==agent
            assert p["capture_us"]//250000==i and p["pose_ref"]==o["body"]["pose_ref"]
            assert p["distant"]["capture_window"]["start_us"]==p["capture_us"]
            check_rays(o)
            st=history[o["stock_event_count"]]
            assert {v["ref"] for v in o["food_visibility"] or []}=={r for r,n in st.items() if n>0}
            expected=[];partial=False;b=o["body"]
            for v in o["food_visibility"] or []:
                pos=initial[v["ref"]]["position"];d=dist(xyz(pos),xyz(b["position"]))
                assert isclose(v["distance"],d,abs_tol=1e-4) and v["in_range"]==(d<=12)
                partial |= v["coverage"]!="complete"
                if v["in_range"] and v["line_of_sight"]:
                    dx,dy,dz=[pos[k]-b["position"][k] for k in "xyz"];yaw=b["yaw"]
                    expected.append(dict(ref=v["ref"],distance=d,forward=-sin(yaw)*dx+cos(yaw)*dz,
                        right=cos(yaw)*dx+sin(yaw)*dz,up=dy,appearance="brown_capped_ovoid"))
            expected.sort(key=lambda x:(x["distance"],x["ref"]))
            partial |= len(expected)>5
            assert p["food"]["coverage"]==("partial" if partial else "complete")
            assert len(p["food"]["visible"])==min(5,len(expected))
            for actual,v in zip(p["food"]["visible"],expected[:5]):
                assert actual["ref"]==v["ref"] and actual["appearance"]==v["appearance"]
                assert all(isclose(actual[k],v[k],abs_tol=1e-4) for k in ("distance","forward","right","up"))
        learning=t["learning"]
        assert all(r["agent_id"]==agent for r in learning["records"])
        if t["active_model"]:
            assert t["active_model"]["agent_id"]==agent
            admission=learning["admission"]
            assert admission["status"]=="ADOPTED" and len(admission["records"])==5
            assert admission["candidate"]["support_count"]==3 and admission["candidate"]["validation_count"]==2
        for c in learning["comparisons"]:
            assert c["F"]["model_ref"]==c["F_prime"]["model_ref"]==c["model_ref"]
            assert c["confirmed"]==(not any(c["prediction_difference"].values()))
            before=t["observations"][c["source"]];after=t["observations"][c["later"]]
            receipt=t["results"][c["operation_id"]]
            assert before["capture_us"]<=receipt["executed_us"]<after["capture_us"]
            assert before["agent_id"]==after["agent_id"]==agent
        for r in learning["records"]:
            assert r["operation_id"] in t["results"] and r["source"] in t["observations"] and r["later"] in t["observations"]
            assert r["acquired"]==t["results"][r["operation_id"]]["acquired"]
        starts=[d for d in t["decisions"].values() if d["exploration_started"]]
        if a["profile"]=="steady":assert not starts
        assert all(d["variation"]["request_exploration"] and d["model_ref"] for d in starts)
        counts=Counter(i["target_ref"] for i in inventory)
        departures=[]
        for o in a["observations"]:
            decision=t["decisions"][o["packet"]["observation_id"]]
            if decision["exploration_started"]:
                visible=o["packet"]["food"]["visible"]
                receipt=t["results"]["op:"+o["packet"]["observation_id"]]
                departures.append(dict(capture_us=o["packet"]["capture_us"],
                    available_observed_stock=sum(history[o["stock_event_count"]][f["ref"]] for f in visible),
                    source=o["packet"]["observation_id"],local_load=decision["variation"]["load"],
                    first_action_status=receipt["status"],measured_yaw=receipt["yaw"],measured_forward=receipt["forward"]))
        summaries[agent]=dict(profile=a["profile"],pickups=len(inventory),patches=len(counts),distance=round(distance,3),
            learned=t["active_model"] is not None,invalidated=learning["invalidated"],
            predictions=len(learning["comparisons"]),exploration_requests=len(starts),departures=departures)
    assert sum(a["pickups"] for a in summaries.values())==len(events)==12*len(stock)-sum(stock.values())
    assert w["guards"]["cross_agent"] and w["guards"]["duplicate_operation"]
    for period in w["periods"]:
        assert {p["ref"]:p["remaining"] for p in period["stock"]}==history[period["stock_event_count"]]
    if w["faults"]:
        assert all(w["guards"][k] for k in ("lost_response","loss_recovered","old_callback"))
        assert any(r["status"]=="expired" for a in s["agents"].values() for r in a["results"].values())
    return dict(scenario=w["scenario"],periods=s["periods"],assignment=s["assignment"],agents=summaries,
        remaining=sum(stock.values()),total_pickups=len(events))
