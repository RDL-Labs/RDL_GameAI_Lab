"""Independent return-trip counting, without granting navigation authority."""
from .check_landmark_day_cycle import check as day_check
from runtime.landmark_return_campaign import ReturnCampaign


def trips(world):
    """One batch per agent/night, only previously uncounted acquisition events."""
    nights=[]
    for aid,a in world["agents"].items():
        seen=set()
        for action in a["actions"]:
            c,r=action["command"],action["result"]
            day=c["capture_us"]//64000000
            if c["capture_us"]%64000000<56000000 or r["status"]!="waited" or day in seen: continue
            seen.add(day)
            nights.append((r["executed_us"],aid,day,action))
    counted=set();out=[]
    for now,aid,day,action in sorted(nights,key=lambda x:(x[0],x[1])):
        pos=action["after"]["position"]
        fresh=[e["operation_id"] for e in (world["stock_events"] or []) if e["agent_id"]==aid
               and e["executed_us"]<=now and e["operation_id"] not in counted]
        if pos["x"]**2+(pos["z"]-6)**2<=100 and fresh:
            counted.update(fresh)
            out.append(dict(agent_id=aid,day=day+1,checked_us=now,night_operation=action["command"]["operation_id"],
                            position=pos,pickup_operations=fresh))
            if len(out)==3: break
    return out


def check(data, *, require_clean_transport=True):
    w,s=data["world"],data["runtime"]["exploration"]
    actual=w["return_campaign"]["events"] or []
    expected=trips(w)
    assert w["return_campaign"]["target"]==3 and actual==expected
    n=len(w["agents"]["npc_a"]["observations"])
    reason="return_target_reached" if len(actual)==3 else "time_limit"
    if reason=="time_limit": assert n==s["periods"]*256
    else:
        assert all(o["packet"]["capture_us"]<=actual[-1]["checked_us"] for a in w["agents"].values() for o in a["observations"])
    replay_type=ReturnCampaign
    if s.get("mb_field_mode") or s.get("harvest_state"):
        class ConfiguredCampaign(ReturnCampaign):
            def __init__(self,*args): super().__init__(*args,mb_field_mode=s.get("mb_field_mode","off"),harvest_state=s.get("harvest_state",False))
        replay_type=ConfiguredCampaign
    summary=day_check(data,replay_type,dict(slots=n,reason=reason), require_clean_transport=require_clean_transport)
    faults={k:sum(a["result"]["status"]==k for agent in w["agents"].values() for a in agent["actions"]) for k in ("expired","stale","stopped")}
    summary.update(strict_acceptance=not any(faults.values()),transport_faults=faults)
    summary.update(end_reason=reason,completed_days=n//256,observed_days=(n+255)//256,
                   return_trips=actual,total_returns=len(actual),observations_per_agent=n)
    return summary


if __name__ == "__main__":
    import argparse
    import gzip
    import json
    import lzma
    from pathlib import Path
    parser=argparse.ArgumentParser()
    parser.add_argument("artifact",type=Path)
    parser.add_argument("--diagnostic",action="store_true",help="Audit timing-dirty evidence without claiming clean acceptance")
    args=parser.parse_args()
    opener=lzma.open if args.artifact.suffix==".xz" else gzip.open
    with opener(args.artifact,"rt",encoding="utf-8") as stream: report=json.load(stream)
    for run in report["runs"]:
        summary=check(run["data"],require_clean_transport=not args.diagnostic)
        if run.get("summary") is not None: assert summary==run["summary"]
        print(json.dumps({k:v for k,v in summary.items() if k not in ("days","agents")},ensure_ascii=False))
