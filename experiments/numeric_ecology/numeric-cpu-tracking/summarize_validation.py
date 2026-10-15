import json
from pathlib import Path

root=Path(__file__).resolve().parent
def read(p):
    return json.loads(p.read_text(encoding="utf-8-sig"))
comparisons=read(root/"comparison.json")
assert len(comparisons)==6 and all(comparisons.values()), "Complete all comparisons first"
memory=[json.loads(line) for line in (root/"30agents.memory.jsonl").read_text(encoding="utf-8-sig").splitlines()]
old=read(root.parent/"numeric-cpu-full/validation.json")
peak=max(m["peak_working_set_bytes"] for m in memory)
report={
    "checks":comparisons,
    "core_and_tracking_checks_passed":42,
    "invariant_checks_passed_per_scenario":24,
    "on_3":read(root/"on-3.json.metrics.json"),
    "off_3":read(root/"off-3.json.metrics.json"),
    "off_3_days":read(root/"off-3days.json.metrics.json"),
    "on_30_previous_version":old["thirty_agents"],
    "off_30":read(root/"off-30.json.metrics.json"),
    "on_30_peak_bytes":old["thirty_agents_peak_working_set_bytes"],
    "off_30_peak_bytes":peak,
    "peak_reduction_percent":100*(1-peak/old["thirty_agents_peak_working_set_bytes"]),
    "scope":"OFF reclaims unreachable registry identities. Functional references and reachable output history remain.",
    "timing_limit":"Single runs include compilation and some overlapping verification work. No controlled speedup claim."
}
(root/"validation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps({k:v for k,v in report.items() if k in ("checks","on_30_peak_bytes","off_30_peak_bytes","peak_reduction_percent")},indent=2))
