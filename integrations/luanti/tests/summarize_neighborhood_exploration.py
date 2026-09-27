"""L13V metrics from saved observations; no data returned to the policy."""
from collections import Counter
import gzip
import json
from pathlib import Path

from .summarize_landmark_exploration import summarize as landmarks


def summarize(series):
    result = landmarks(series)
    outcomes, surveys, skips = Counter(), 0, 0
    for day in series["days"]:
        latest = {}
        for decision in day["data"]["runtime"]["exploration"]["decisions"].values():
            n = decision["neighborhood"]
            if n["survey"] is not None:
                latest[n["survey"]["survey_id"]] = n
        for n in latest.values():
            if n["phase"] == "skipped":
                skips += 1
            else:
                surveys += 1
                outcomes[n["outcome"] or "unfinished_at_day_end"] += 1
    state = series["state"]
    candidate = state["candidate"]
    relation = candidate["common_relation_signature"] if candidate else None
    result.update(survey_attempts=surveys, survey_outcomes=dict(outcomes), model_skips=skips,
                  candidate_kind=relation["kind"] if relation else None,
                  formation_day=next((d["start"]["day"] for d in series["days"]
                      if relation and d["start"]["request"]["episode_id"] == relation["formation_episode"]), None),
                  inspection_day=next((d["start"]["day"] for d in series["days"]
                      if d["receipt"]["sleep"]["inspection"]), None))
    return result


if __name__ == "__main__":
    import sys
    matrix = json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes()))
    print(json.dumps(dict(primary=[summarize(s) for s in matrix["series"]],
        revisit=[dict(scenario=b["scenario"], comparison=b["comparison"],
                      active=summarize(dict(b["active"], days=b["active"]["days"][-1:])),
                      inactive=summarize(dict(b["inactive"], days=b["inactive"]["days"][-1:])))
                 for b in matrix["revisit_branches"]]), ensure_ascii=False, indent=2))
