"""Exact structured comparison (object key order is not significant)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def differences(a, b, path=""):
    if isinstance(a, dict) and isinstance(b, dict):
        if a.keys() != b.keys():
            yield [path, "keys", sorted(a.keys() - b.keys()), sorted(b.keys() - a.keys())]
        for key in sorted(a.keys() & b.keys()):
            yield from differences(a[key], b[key], path + "/" + str(key))
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            yield [path, "length", len(a), len(b)]
        for i, (x, y) in enumerate(zip(a, b)):
            yield from differences(x, y, path + "/" + str(i))
    elif type(a) is not type(b) or a != b:
        yield [path, "value", a, b]

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

checks = {}
base = read(ROOT.parent / "numeric-cpu/baseline-result.json")
new = read(ROOT / "result.json")
checks["three_agents_one_day"] = list(differences(base, new))
if (ROOT / "roundtrip.json").exists():
    checks["fresh_process_numeric_snapshot"] = list(differences(new, read(ROOT / "roundtrip.json")))
if (ROOT / "30agents-result.json").exists():
    old30 = read(ROOT.parent / "julia-30agents-3days/result.json")
    new30 = read(ROOT / "30agents-result.json")
    checks["thirty_agents_first_day"] = list(differences(old30["daily"][0], new30["daily"][0]))
    checks["thirty_agents_initial_state"] = list(differences(old30["day_starts"][0], new30["day_starts"][0]))
(ROOT / "parity-report.json").write_text(json.dumps(checks, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({k: len(v) for k, v in checks.items()}))
assert all(not d for d in checks.values()), "Parity differences: see parity-report.json"
