"""Resource encounter metrics, separated from discovery days and pickup."""
from collections import Counter
import gzip
import json
from pathlib import Path
from .summarize_neighborhood_exploration import summarize as neighborhood


def summarize(series):
    r=neighborhood(series)
    seen,maximum,visible_frames,eligible,occluded=Counter(),0,0,0,0
    nearest={i:float("inf") for i in range(1,6)}
    ranged,hidden=Counter(),Counter()
    active,probe=0,0
    first_by_day=[]
    for day in series["days"]:
        world=day["data"]["world"]
        slots={f["ref"]:i+1 for i,f in enumerate(world["foods_initial"])}
        first=None
        for o in world["observations"]:
            visible=o["packet"]["food"]["visible"]
            maximum=max(maximum,len(visible));visible_frames+=bool(visible)
            eligible+=sum(v["in_range"] for v in o["food_visibility"])
            occluded+=sum(v["in_range"] and not v["line_of_sight"] and v["coverage"]=="complete" for v in o["food_visibility"])
            for v in o["food_visibility"]:
                site=slots[v["ref"]];nearest[site]=min(nearest[site],v["distance"])
                ranged[site]+=v["in_range"]
                hidden[site]+=v["in_range"] and not v["line_of_sight"] and v["coverage"]=="complete"
            seen.update(slots[f["ref"]] for f in visible)
            if visible and first is None:first=dict(day=day["start"]["day"],capture_us=o["packet"]["capture_us"],sites=[slots[f["ref"]] for f in visible])
        if first:first_by_day.append(first)
        decisions=day["data"]["runtime"]["exploration"]["decisions"].values()
        active+=sum(d["reason"]=="active_M_B" for d in decisions)
        probe+=sum(d["reason"]=="validation_probe" for d in decisions)
    r.update(visible_frames=visible_frames,max_simultaneously_visible=maximum,site_observations=dict(seen),
             in_range_resource_checks=eligible,occluded_resource_checks=occluded,first_food_by_day=first_by_day,
             active_route_actions=active,validation_route_actions=probe)
    r["site_audit"]={i:dict(minimum_capture_distance=round(nearest[i],3),in_range=ranged[i],occluded=hidden[i],visible=seen[i]) for i in range(1,6)}
    return r


if __name__=="__main__":
    import sys
    a=json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes()))
    print(json.dumps([summarize(s) for s in a["series"]],ensure_ascii=False,indent=2))
