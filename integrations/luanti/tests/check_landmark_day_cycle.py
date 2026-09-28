"""Wire replay and physical continuity audit; World truth never enters the agent."""
from collections import Counter
from math import sin, cos, radians
from runtime.landmark_day_cycle import DayCycleExploration, phase, DAY_US
from .check_multi_resource import check as base_check
from .check_resource_exploration import round_node


def check(data):
    summary=base_check(data,DayCycleExploration)
    w,s=data["world"],data["runtime"]["exploration"]
    home=w["home_tower"]["position"]
    reports={}
    for aid,a in s["agents"].items():
        world=w["agents"][aid]
        days=[]
        memory=None
        for ob in world["observations"]:
            p=ob["packet"];f=p["skyline"];rays=ob["skyline_rays"]
            assert len(rays)==39
            expected=[];partial=False
            for i,r in enumerate(rays):
                el=(i//13)*15;az=-90+(i%13)*15
                assert r["elevation"]==el and r["azimuth"]==az and 1<=r["samples"]<=192
                partial |= r["status"] in ("unloaded","unclassified")
                if r["status"]!="sampled": continue
                hit=r["hit"];d=hit["distance"]
                assert d==r["samples"]*.25 and d<=48
                b=ob["body"];theta=b["yaw"]-radians(az)
                xyz=dict(x=round_node(b["position"]["x"]-sin(theta)*cos(radians(el))*d),
                    y=round_node(b["position"]["y"]+.5+sin(radians(el))*d),
                    z=round_node(b["position"]["z"]+cos(theta)*cos(radians(el))*d))
                assert hit["position"]==xyz
                colors=dict(grass="green",dirt="brown",stone="gray",trunk="brown",leaves="green",water="blue",
                    rock_gray="gray",rock_red="red",patch_brown="brown",patch_gray="gray",tower="ochre")
                expected.append(dict(ref=f"ray:{el}:{i%13}",color=colors[hit["node"].removeprefix("rdl_bridge:exploration_")],
                    azimuth=[max(-90,az-7.5),min(90,az+7.5)],elevation=el,
                    range_band="near" if d<=8 else ("mid" if d<=24 else "far")))
            assert f["features"]==expected and f["coverage"]==("partial" if partial else "complete")
            state=a["decisions"][p["observation_id"]]["day_cycle"]
            assert state["phase"]==phase(p["capture_us"])
            if memory is None: memory=state["home_memory"]
            assert state["home_memory"]==memory
        actions=world["actions"]
        for day in range(s["periods"]):
            subset=[x for x in actions if x["command"]["capture_us"]//DAY_US==day]
            night=[x for x in subset if phase(x["command"]["capture_us"])=="night"]
            assert len(night)==32 and all(x["command"]["kind"]=="wait" and x["result"]["status"]=="waited" for x in night)
            assert all(x["before"]["position"]==night[0]["before"]["position"]==x["after"]["position"] for x in night)
            d=a["decisions"][night[0]["command"]["source_id"]]["day_cycle"]
            assert len(d["nights"])==day+1 and len(d["nights"][-1]["records"])<=16
            for item in d["nights"][-1]["records"]:
                assert item["observation"] in a["observations"] and item["operation"] in a["results"]
                assert a["commands"][item["observation"]]["kind"] != "wait"
                assert a["observations"][item["observation"]]["capture_us"]//DAY_US == day
            pos=night[0]["before"]["position"]
            error=((pos["x"]-home["x"])**2+(pos["z"]-home["z"])**2)**.5
            return_actions=[x for x in subset if phase(x["command"]["capture_us"])=="return"]
            return_counts=Counter(x["result"]["status"] for x in return_actions)
            counts=Counter(x["result"]["status"] for x in subset)
            assert not any(counts[k] for k in ("expired","stale","stopped"))
            days.append(dict(day=day+1,return_outcome=d["return_state"]["outcome"],
                world_home_distance=round(error,3),within_home_region=error<=10,
                pickups=counts["picked_up"],moved=counts["moved"],blocked=counts["blocked"],
                return_moves=return_counts["moved"],return_turns=return_counts["turned"],
                night_waits=len(night),night_records=len(d["nights"][-1]["records"]),
                night_start_fatigue=round(d["fatigue"],6),
                night_end_fatigue=round(a["decisions"][night[-1]["command"]["source_id"]]["day_cycle"]["fatigue"],6)))
        reports[aid]=dict(home_memory=memory and memory["color"],days=days)
    summary["days"]=reports
    return summary
