"""Experimenter-only spatial and resource accounting for the L14B seed panel.

Exact positions, patch labels and stocks are never supplied to the agents.
Occupancy counts regular capture samples, not unique observations or evidence
support. An unchanged position also includes legitimate turns and pickups.
"""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from math import dist, floor
from pathlib import Path

from .run_exploration_series import ROOT, write

CELL_SIZE = 8
LATE_START_US = 160_000_000  # Start of period 11; periods are 16 seconds.


def load(path):
    raw = Path(path).read_bytes()
    return json.loads(gzip.decompress(raw) if Path(path).suffix == ".gz" else raw)


def xyz(position):
    return tuple(position[k] for k in "xyz")


def occupancy(observations, actions):
    cells = Counter((floor(o["body"]["position"]["x"] / CELL_SIZE),
                     floor(o["body"]["position"]["z"] / CELL_SIZE)) for o in observations)
    n = len(observations)
    counts = {f"{x},{z}": count for (x, z), count in sorted(cells.items())}
    peak = max(cells.values(), default=0)
    lengths = [dist(xyz(a["before"]["position"]), xyz(a["after"]["position"])) for a in actions]
    return dict(samples=n, visited_cells=len(cells), cell_counts=counts,
        dominant_cells=[key for key, count in counts.items() if count == peak],
        max_cell_share=round(peak / n, 6) if n else None,
        distance=round(sum(lengths), 3),
        moved_actions=sum(length > 1e-4 for length in lengths),
        position_unchanged_actions=sum(length <= 1e-4 for length in lengths),
        action_statuses=dict(sorted(Counter(a["result"]["status"] for a in actions).items())),
        action_reasons=dict(sorted(Counter(a["command"]["reason"] for a in actions).items())),
        action_count=len(actions))


def fixed_conditions(data):
    w = data["world"]
    s = data["runtime"]["exploration"]
    return dict(scenario=w["scenario"], periods=w["period_count"],
        assignment=w["assignment"], control=w["control"], faults=w["faults"],
        terrain=w["terrain"],
        resources=[dict(position=p["position"], initial=p["initial"]) for p in w["stock_initial"]],
        agents={agent: dict(profile=a["profile"], seed=s["agents"][agent]["seed"],
            position=a["initial_body"]["position"], yaw=a["initial_body"]["yaw"])
            for agent, a in w["agents"].items()})


def metrics(data):
    w = data["world"]
    s = data["runtime"]["exploration"]
    labels = {p["ref"]: f"P{i + 1}" for i, p in enumerate(w["stock_initial"])}
    agents = {}
    for agent, a in sorted(w["agents"].items()):
        t = s["agents"][agent]
        inventory = a["inventory"] or []
        counts = Counter(labels[i["target_ref"]] for i in inventory)
        first_seen = {}
        for o in a["observations"]:
            for food in o["packet"]["food"]["visible"]:
                first_seen.setdefault(labels[food["ref"]], o["packet"]["capture_us"])
        late_obs = [o for o in a["observations"] if o["packet"]["capture_us"] >= LATE_START_US]
        late_actions = [v for v in a["actions"] if v["command"]["capture_us"] >= LATE_START_US]
        late_blocked = {v["command"]["operation_id"] for v in late_actions if v["result"]["status"] == "blocked"}
        admission = t["learning"]["admission"]
        agents[agent] = dict(profile=a["profile"], pickups=len(inventory),
            harvested_by_patch=dict(sorted(counts.items())), observed_patches=dict(sorted(first_seen.items())),
            pickups_by_ten_periods=[sum(start <= i["acquired_us"] < start + 160_000_000
                for i in inventory) for start in (0, 160_000_000, 320_000_000)],
            admission_status=admission["status"] if admission else "NOT_EVALUATED",
            invalidated=t["learning"]["invalidated"],
            predictions=len(t["learning"]["comparisons"]),
            exploration_requests=sum(d["exploration_started"] for d in t["decisions"].values()),
            late_block_causes=dict(sorted(Counter(v["audit"]["reason"] for v in a.get("terrain_moves", [])
                if v["operation_id"] in late_blocked).items())),
            whole=occupancy(a["observations"], a["actions"]),
            late=occupancy(late_obs, late_actions))
    return dict(run_id=w["run_id"], seed=s["seed"], assignment=s["assignment"],
        total_pickups=sum(a["pickups"] for a in agents.values()),
        remaining_by_patch={labels[p["ref"]]: p["remaining"] for p in w["final_stock"]},
        agents=agents)


def panel_runs(panel, root=ROOT):
    ref = panel["provenance"]["historical_baseline"]
    path = root / ref["file"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == ref["sha256"], "baseline hash differs"
    baseline = next(r for r in load(path)["runs"] if r["data"]["world"]["run_id"] == ref["run_id"])
    assert baseline["data"]["runtime"]["exploration"]["seed"] == ref["seed"]
    return [baseline, *panel["runs"]]


def analyze(panel, root=ROOT):
    assert panel["schema"] == "l14b-seed-panel-v1"
    assert not panel.get("pending") and not panel.get("failure"), "incomplete panel"
    declared = panel["provenance"]["predeclared"]
    assert len(panel["runs"]) == len(declared)
    for item, case in zip(panel["runs"], declared):
        w, s = item["data"]["world"], item["data"]["runtime"]["exploration"]
        for key in ("scenario", "assignment", "control", "faults"):
            assert w[key] == case[key], (key, w[key], case[key])
        assert s["periods"] == case["periods"] and s["seed"] == case["seed"]
    runs = panel_runs(panel, root)
    fixed = None
    for item in runs:
        conditions = fixed_conditions(item["data"])
        for a in conditions["agents"].values():
            assert a.pop("seed") == item["data"]["runtime"]["exploration"]["seed"]
        if fixed is None:
            fixed = conditions
        assert conditions == fixed, "conditions other than exploration seed changed"
    return dict(schema="l14b-seed-analysis-v1", fixed_conditions_equal=True,
        definitions=dict(cell_size=CELL_SIZE, cell_coordinates="floor(x/8), floor(z/8); no clipping",
            late_start_us=LATE_START_US, occupancy="regular capture sample count; not evidence support",
            observed_patch="appeared in accepted local food observation, not hidden line-of-sight audit",
            stationarity="actual position unchanged within 0.0001 node; includes turns/waits/pickups",
            inference="finite seed panel; no terrain or timing counterfactual and no pure profile effect"),
        runs=[metrics(r["data"]) for r in runs])


def main():
    p = argparse.ArgumentParser()
    p.add_argument("panel", type=Path)
    p.add_argument("output", type=Path)
    args = p.parse_args()
    result = analyze(load(args.panel))
    write(args.output, result)
    for r in result["runs"]:
        print(r["seed"], r["total_pickups"], r["remaining_by_patch"])
        for agent, a in r["agents"].items():
            print(agent, a["harvested_by_patch"], a["admission_status"],
                  "requests", a["exploration_requests"], "late", a["late"])


if __name__ == "__main__":
    main()
