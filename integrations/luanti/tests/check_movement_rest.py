"""Independent body/rest audits plus exact accepted-wire replay."""
from collections import Counter
from runtime.movement_rest import RestResourceExploration
from .check_terrain_resource import check as check_terrain


def check(data, loop_type=RestResourceExploration):
    summary=check_terrain(data,loop_type)
    for aid,a in data["runtime"]["exploration"]["agents"].items():
        world=data["world"]["agents"][aid]
        actions={r["command"]["source_id"]:r for r in world["actions"]}
        starts=[];waits=0;recoveries=0.;resumed=0
        per_period=Counter()
        for oid,d in a["decisions"].items():
            meta=d["rest"];s=meta["state"]
            assert 0<=s["fatigue"]<=12 and 0<=s["residual"]<=4
            assert len(set(s["charged"]))==len(s["charged"])
            assert len(set(s["consumed"]))==len(s["consumed"])
            recoveries+=meta["accounting"]["recovery"]
            if meta["transition"]=="started":
                starts.append(dict(source=oid,reasons=s["active"]["reasons"],capture_us=a["observations"][oid]["capture_us"]))
                per_period[d["period"]]+=1
            if meta["transition"]=="resumed":resumed+=1
            if d["reason"]=="finite_rest":
                r=actions[oid]
                assert r["command"]["kind"]=="wait"
                assert r["before"]==r["after"] and r["result"]["status"] in ("waited","expired","stopped","stale")
                assert s["active"]["decisions"]<=4 and not meta["priority"]
                waits+=1
        assert all(n<=4 for n in per_period.values())
        if a["rest_mode"]=="disabled":assert waits==0
        if waits:
            ds=list(a["decisions"].values())
            assert any(before["reason"]=="finite_rest" and after["rest"]["accounting"]["recovery"]>0
                       and after["rest"]["state"]["fatigue"]<before["rest"]["state"]["fatigue"]
                       for before,after in zip(ds,ds[1:])),"no confirmed recovery after rest"
        summary["agents"][aid]["rest"]=dict(mode=a["rest_mode"],starts=starts,waits=waits,resumed=resumed,
            recovery=round(recoveries,6),max_fatigue=max(d["rest"]["state"]["fatigue"] for d in a["decisions"].values()),
            interrupted_surveys=sum(d["neighborhood"].get("outcome")=="rest_interrupted" for d in a["decisions"].values()))
    return summary
