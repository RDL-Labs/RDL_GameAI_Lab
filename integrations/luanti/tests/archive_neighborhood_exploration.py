"""Archive original World snapshots with their hashes and final-code replay provenance."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from .run_exploration_series import ROOT, OUTPUT, write
from .check_learned_exploration import check_matrix


def archive(matrix, legacy, destination):
    data = json.loads(gzip.decompress(Path(matrix).read_bytes()))
    assert len(data["series"]) == 2
    verified = {}
    series = data["series"] + [b[k] for b in data["revisit_branches"] for k in ("active", "inactive")]
    for s in series:
        for day in s["days"]:
            source = day["source"]
            raw = (OUTPUT / source["file"]).read_bytes()
            assert hashlib.sha256(raw).hexdigest() == source["sha256"]
            assert json.loads(raw.decode("utf-8-sig")) == day["data"]
            assert source["file"] not in verified or verified[source["file"]] == source["sha256"]
            verified[source["file"]] = source["sha256"]
    raw = Path(legacy).read_bytes()
    data["legacy_regression"] = json.loads(raw.decode("utf-8-sig"))
    data["provenance"]["legacy_source"] = dict(file=Path(legacy).name, sha256=hashlib.sha256(raw).hexdigest())
    data["provenance"]["verified_snapshot_sha256"] = verified
    data["provenance"]["final_source_sha256"] = {
        f: hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in data["provenance"]["source_sha256"]}
    data["validation_history"] = [
        "During capture: added input guard against replacing an ordinary pending day with a revisit seed.",
        "During capture: current visible Food explicitly prevents the no-discovery model from skipping a survey.",
        "During capture: wholly incomplete days leave the canonical count adapter empty instead of initializing it from a partial observation.",
        "Audit now also checks equal measured heading before the paired first-action difference.",
        "Full regression found that the default extension hook captured the old function before failure injection; restored call-time delegation so the existing atomic-failure regression remains effective.",
        "Original World snapshots remain unchanged. Final code replays all saved requests, decisions, results, Sleep and T1 state exactly.",
        "Repeated branch prefixes are shared historical evidence, not additional World runs or support votes."]
    check_matrix(data)
    write(Path(destination), data)
    print(json.dumps(dict(file=str(destination), unique_new_world_runs=len(verified),
                         legacy_runs=1, bytes=Path(destination).stat().st_size,
                         sha256=hashlib.sha256(Path(destination).read_bytes()).hexdigest())))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("matrix"); p.add_argument("legacy"); p.add_argument("destination")
    args = p.parse_args()
    archive(args.matrix, args.legacy, args.destination)
