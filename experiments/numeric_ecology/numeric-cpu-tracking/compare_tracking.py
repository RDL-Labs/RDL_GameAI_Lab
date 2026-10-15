import json
from pathlib import Path

root = Path(__file__).resolve().parent
def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

checks = {}
off3 = read(root / "off-3.json")
checks["three_agents_on_off_full_result"] = off3 == read(root / "on-3.json")
checks["three_agents_original_full_result"] = off3 == read(root.parent / "numeric-cpu/baseline-result.json")
checks["off_snapshot_fresh_process"] = off3 == read(root / "off-3-restored.json")
if (root / "off-30.json").exists():
    checks["thirty_agents_on_off_full_result"] = read(root / "off-30.json") == read(root.parent / "numeric-cpu-full/30agents-result.json")
if (root / "off-3days.json").exists():
    multi = read(root / "off-3days.json")
    original = read(root.parent / "julia-fixed-progress/result.json")
    checks["three_days_daily_records"] = multi["daily"] == original["daily"][:3]
    checks["three_days_day_starts"] = multi["day_starts"] == original["day_starts"][:3]
(root / "comparison.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
print(json.dumps(checks))
assert all(checks.values()), "ON/OFF comparison failed"
