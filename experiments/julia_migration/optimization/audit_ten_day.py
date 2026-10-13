"""Independent saved-output audit; no simulation or Julia required."""
import hashlib
import json
import math
import sys
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def audit(root):
    spec = read(root / "spec.json")
    assert spec["config"]["days"] == 10
    results = [read(root / variant / "result.json") for variant in ("old", "new")]
    assert results[0] == results[1], "old/new result mismatch"
    measures = {}
    for variant, result in zip(("old", "new"), results):
        assert result["ended_us"] == 10 * spec["clock"]["day_us"]
        assert len(result["daily"]) == 10
        assert len(result["day_starts"]) == 10
        assert len(result["final_agents"]) == 3
        assert all(sum(c.values()) == 172800 for c in result["counts"].values())
        for state in [*result["daily"], result]:
            agents = state.get("physical", state.get("final_agents"))
            supply = result["initial_food"] + state["replenished_food"]
            held = sum(a["inventory"] + a["personal_stock"] for a in agents.values())
            assert supply == state["ground"] + state["shared_stock"] + held + state["consumed"]
            for a in agents.values():
                assert a["inventory"] >= 0 and a["personal_stock"] >= 0
                b = a["body"]
                assert all(math.isfinite(v) for v in b.values() if isinstance(v, (int, float)))
                assert 0 <= b["reserve"] <= 100 and 0 <= b["strain"] <= 1
                assert 0 <= b["burst"] <= 10 and 0 <= b["damage"] <= 1
        for i in range(1, 10):
            assert result["daily"][i-1]["physical"] == result["day_starts"][i]
        # Final output has a different schema (no standalone yaw/loop fields).
        for actor, final in result["final_agents"].items():
            for key in ("position", "body", "inventory", "personal_stock"):
                assert result["daily"][-1]["physical"][actor][key] == final[key]
        measures[variant] = read(root / variant / "summary.json")["measurement"]
    return {
        "root": str(root.resolve()), "days": 10, "agents": 3,
        "operations_per_variant": 518400, "exact_decoded_results_equal": True,
        "daily_and_final_conservation": True, "overnight_continuity": True,
        "spec_sha256": hashlib.sha256((root / "spec.json").read_bytes()).hexdigest(),
        "measurements": measures,
    }, results[1]


if __name__ == "__main__":
    reports = []
    reference = None
    for value in sys.argv[1:]:
        root = Path(value)
        report, result = audit(root)
        if reference is not None:
            report["cross_environment_exact_equal"] = reference == result
        reference = result
        (root / "independent-audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        reports.append(report)
    print(json.dumps(reports, indent=2))
