"""Experimenter metrics; no changes to runtime choices or learning material."""
from collections import Counter
import gzip
import json
from pathlib import Path


def summarize(series):
    statuses, reasons, terminations, colors = Counter(), Counter(), Counter(), Counter()
    selected, continued, rays, ob_count, distance = 0, 0, 0, 0, 0
    for day in series["days"]:
        world, state = day["data"]["world"], day["data"]["runtime"]["exploration"]
        statuses.update(r["status"] for r in state["results"].values())
        reasons.update(d["reason"] for d in state["decisions"].values())
        distance += world["controller"]["distance"]
        ob_count += len(world["observations"])
        rays += sum(len(o["landmark_rays"]) for o in world["observations"])
        ended, held = set(), set()
        for d in state["decisions"].values():
            st = d["landmark"]; goal = st["goal"]
            if st["selection_index"] is not None:
                selected += 1; colors[goal["current_feature"]["color"]] += 1
            if goal and st["stage"] == "active" and goal["operations"] > 0:
                held.add(goal["goal_id"])
            if goal and st["stage"] == "terminated" and goal["goal_id"] not in ended:
                terminations[st["outcome"]] += 1; ended.add(goal["goal_id"])
        continued += len(held)
    return dict(scenario=series["scenario"], days=len(series["days"]),
                summary=series["state"]["summary"], observations=ob_count, rays=rays,
                actions=dict(statuses), decisions=dict(reasons), selected_goals=selected,
                goals_continued_after_body_result=continued, goal_terminations=dict(terminations),
                selected_colors=dict(colors), distance=round(distance, 3))


if __name__ == "__main__":
    import sys
    a = json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes()))
    print(json.dumps([summarize(s) for s in a["series"]], ensure_ascii=False, indent=2))
