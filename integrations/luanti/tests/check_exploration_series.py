"""Replay L13R series and independently check each real Luanti day."""
from copy import deepcopy
import gzip
import json
from math import isclose
from pathlib import Path
import sys

from runtime.exploration_series import ExplorationSeries, digest
from .check_exploration import check


def deliveries(data):
    # Explicit projection: private World positions, shape IDs and schedules cannot enter memory.
    return [dict(kind=d["kind"], request=deepcopy(d["request"]), response=json.loads(d["response_wire"]))
            for d in data["world"]["deliveries"]]


def reset_signature(data):
    w = data["world"]
    return dict(scenario=w["scenario"], body={k: v for k, v in w["initial_body"].items() if k != "pose_ref"},
                food=w["food_initial"], mountains=w["mountains"])


def check_series(artifact, check_world=True):
    assert artifact["schema"] == "l13r-real-series-v1"
    config = artifact["config"]
    series = ExplorationSeries(config["series_id"], config["mode"], config["max_days"])
    signature = None
    runs = set()
    for day in artifact["days"]:
        data = day["data"]
        if check_world:
            check(data)
        run = data["world"]["run_id"]
        assert run not in runs
        runs.add(run)
        current = reset_signature(data)
        if signature is None:
            signature = current
        else:
            assert current == signature, "initial World/body changed between days"
        assert current["scenario"] == artifact["scenario"]
        start = series.start_day(dict(episode_id=day["episode_id"], run_id=run))
        assert start == day["start"]
        history = series.history()
        assert digest(history) == day["history_digest"]
        assert len(history) == len(start["history_refs"])
        assert not start["history_consumed_by_policy"]
        request = dict(episode_id=day["episode_id"], run_id=run, deliveries=deliveries(data))
        receipt = series.close_day(request)
        assert receipt == day["receipt"]
        # Exactly-once archival is separate from World operation deduplication.
        assert series.close_day(request) == receipt
        assert receipt["evidence_digest"] == digest(data["runtime"]["exploration"])
        assert receipt["metrics"]["first_food_us"] == data["world"].get("first_food_us")
    assert series.summary() == artifact["summary"]
    assert series.summary()["status"] in ("discovered", "undiscovered_at_limit")
    assert len(runs) == series.summary()["completed_days"]
    return series.summary()


def check_matrix(artifact):
    assert artifact["schema"] == "l13r-real-matrix-v1"
    assert len(artifact["series"]) == 4
    summaries = [check_series(a) for a in artifact["series"]]
    by = {(a["scenario"], a["config"]["mode"]): a for a in artifact["series"]}
    assert set(by) == {(s, m) for s in ("right", "no_strip") for m in ("memory", "reset")}
    run_ids = [d["data"]["world"]["run_id"] for a in artifact["series"] for d in a["days"]]
    assert len(run_ids) == len(set(run_ids)) == 62
    for scenario in ("right", "no_strip"):
        memory, reset = by[scenario, "memory"], by[scenario, "reset"]
        assert reset_signature(memory["days"][0]["data"]) == reset_signature(reset["days"][0]["data"])
        expected = 1 if scenario == "right" else 30
        assert memory["summary"]["completed_days"] == reset["summary"]["completed_days"] == expected
        assert memory["summary"]["status"] == reset["summary"]["status"]
        assert memory["summary"]["discovery_day"] == (1 if scenario == "right" else None)
        for left, right in zip(memory["days"], reset["days"]):
            def sequence(day):
                return [(a["command"]["kind"], a["command"]["amount"], a["command"]["reason"], a["result"]["status"])
                        for a in day["data"]["world"]["actions"]]
            assert sequence(left) == sequence(right), "fixed-policy baseline action sequences differ"
            assert isclose(left["receipt"]["metrics"]["distance"], right["receipt"]["metrics"]["distance"], abs_tol=.001)
    return summaries


def read_artifact(path):
    path = Path(path)
    raw = gzip.decompress(path.read_bytes()) if path.suffix == ".gz" else path.read_bytes()
    return json.loads(raw.decode("utf-8-sig"))


if __name__ == "__main__":
    data = read_artifact(sys.argv[1])
    print(json.dumps(check_matrix(data) if data["schema"] == "l13r-real-matrix-v1" else check_series(data), indent=2))
