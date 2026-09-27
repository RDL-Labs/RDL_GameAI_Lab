"""Extract unchanged L10B frames and factual results from checked World runs."""
import hashlib
import json
from pathlib import Path
import sys

from .check_multi_sensory_learning import check


def extract(path):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    check(data)
    runs = {"source_file": path.name, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "scenario": data["world"]["scenario"], "run_id": data["sensory"]["run_id"],
            "frames": data["sensory"]["frames"], "by_agent": {}}
    for agent, world in data["world"]["by_agent"].items():
        learning = data["learning"]["by_agent"][agent]
        trials = []
        for episode in world["episodes"]:
            op = episode["operation_id"]
            decision = learning["operations"][op]["decision"]
            trials.append({"request": learning["operations"][op]["request"],
                "result": learning["results"][op]["result"],
                "expected_action": decision["action"], "expected_prediction": decision["prediction"]["status"],
                "world": {key: episode[key] for key in ("hidden_blocked", "actions", "deposited", "start", "finish",
                    "authority_consumptions", "base_stock_before", "base_stock_after")}})
        runs["by_agent"][agent] = {"activate": world["activate"], "reverse": world["reverse"], "trials": trials}
    return runs


if __name__ == "__main__":
    output = Path(sys.argv[1])
    runs = [extract(Path(path)) for path in sys.argv[2:]]
    assert {r["scenario"] for r in runs} == {"opposite", "a_only", "b_only"}
    output.write_text(json.dumps({"schema": "luanti-l10b-replay-v1",
        "provenance": "Actual Luanti L10B shared World runs; unchanged accepted frames and result facts. "
                      "Replay rebuilds independent canonical review and remints decision IDs; original IDs remain in this file.",
        "runs": runs}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
