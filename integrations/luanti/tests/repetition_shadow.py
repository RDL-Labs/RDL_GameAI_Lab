"""Finite offline shadow. No action authority; only acquired history is input."""
import argparse
from copy import deepcopy
import gzip
import hashlib
import json
from pathlib import Path

from .diagnose_movement_history import diagnose_window, analyze
from .run_exploration_series import ROOT, write

SCHEMA = "l15a-repetition-shadow-v1"
SCALE = 100000000
# Fixed before replay: identical increments, threshold and evidence; decay only.
DECAY_TICKS_PER_US = {"fast": 100, "standard": 25, "persistent": 1}
MAX_OBSERVATIONS = 1920


class RepetitionShadow:
    """One run, three independently bound agents; atomic in-process replay only."""
    def __init__(self):
        self.binding = None
        self.agents = {}

    def observe(self, records):
        p = records[-1]["observation"]
        binding = tuple(p[k] for k in ("run_id", "world_epoch", "clock_id"))
        if self.binding is not None and self.binding != binding:
            raise ValueError("shadow_binding")
        aid, oid, now = p["agent_id"], p["observation_id"], p["capture_us"]
        # Purpose/decision metadata is neither input to admission nor replay identity.
        payload = [{k: r[k] for k in ("observation", "command", "result")} for r in records]
        fingerprint = hashlib.sha256(json.dumps(payload, sort_keys=True, allow_nan=False).encode()).hexdigest()
        previous = self.agents.get(aid)
        if previous is None and len(self.agents) >= 3:
            raise ValueError("agent_budget")
        state = ({k: v.copy() if isinstance(v, (dict, set)) else v for k, v in previous.items()}
                 if previous else dict(time=None, receipts={}, consumed=set(),
            levels={k: 0 for k in DECAY_TICKS_PER_US}, requests={k: False for k in DECAY_TICKS_PER_US}))
        if oid in state["receipts"]:
            old_hash, old_result = state["receipts"][oid]
            if old_hash != fingerprint:
                raise ValueError("observation_conflict")
            return deepcopy(old_result)
        if len(state["receipts"]) >= MAX_OBSERVATIONS:
            raise ValueError("observation_budget")
        if state["time"] is not None and now <= state["time"]:
            raise ValueError("capture_order")
        row = diagnose_window(records, purpose_scoped=False)
        elapsed = 0 if state["time"] is None else now - state["time"]
        operations = row["operations"]
        full = len(records) == 9 and len(operations) == 8
        overlap = bool(state["consumed"].intersection(operations))
        admitted = full and row["repetition_eligible"] and not overlap
        reason = ("contribution" if admitted else "unknown" if row["status"] == "unknown"
                  else "insufficient_history" if not full else "overlapping_operations" if overlap
                  else "no_recurrence_in_window")
        profiles = {}
        for name, decay in DECAY_TICKS_PER_US.items():
            before = state["levels"][name]
            decayed = max(0, before - elapsed * decay)
            level = min(4*SCALE, decayed + (SCALE if admitted else 0))
            request = level >= 2*SCALE
            profiles[name] = dict(residual_ticks=level, residual=level/SCALE,
                decay_ticks=before-decayed, contribution_ticks=SCALE if admitted else 0,
                would_request_reassessment=request,
                threshold_crossed=request and not state["requests"][name])
            state["levels"][name], state["requests"][name] = level, request
        if admitted:
            state["consumed"].update(operations)
        state["time"] = now
        row["shadow"] = dict(admitted=admitted, reason=reason, profiles=profiles)
        state["receipts"][oid] = (fingerprint, deepcopy(row))
        self.binding = binding
        self.agents[aid] = state
        return deepcopy(row)


def replay(data):
    shadow = RepetitionShadow()
    result = analyze(data, diagnostic=shadow.observe)
    result["shadow_summary"] = {}
    for aid, rows in result["windows"].items():
        result["shadow_summary"][aid] = dict(
            contributions=sum(r["shadow"]["admitted"] for r in rows),
            profiles={name: dict(
                max_residual=max(r["shadow"]["profiles"][name]["residual"] for r in rows),
                threshold_crossings=sum(r["shadow"]["profiles"][name]["threshold_crossed"] for r in rows),
                request_observations=sum(r["shadow"]["profiles"][name]["would_request_reassessment"] for r in rows),
                first_request_us=next((r["capture_us"] for r in rows if r["shadow"]["profiles"][name]["would_request_reassessment"]), None)
            ) for name in DECAY_TICKS_PER_US})
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    paths = [ROOT/"tests/fixtures"/n for n in (
        "luanti_l15a_steering_replay.json.gz", "luanti_l15a_tie_break_replay.json.gz")]
    report = dict(schema=SCHEMA, authority="offline shadow; no action change",
        decay_per_second={k:v/100 for k,v in DECAY_TICKS_PER_US.items()}, threshold=2, cap=4,
        provenance=dict(inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
            code={n:hashlib.sha256(Path(__file__).with_name(n).read_bytes()).hexdigest()
                  for n in ("repetition_shadow.py", "diagnose_movement_history.py")}), runs=[])
    for path in paths:
        for run in json.loads(gzip.decompress(path.read_bytes()))["runs"]:
            result = replay(run["data"])
            report["runs"].append(result)
            print(json.dumps(dict(run_id=result["run_id"], summary=result["shadow_summary"])), flush=True)
    write(args.output, report)


if __name__ == "__main__":
    main()
