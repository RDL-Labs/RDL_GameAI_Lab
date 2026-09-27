"""Keep actual L10C inputs, results and World execution evidence for finite replay."""
import hashlib
import json
from pathlib import Path
import sys

from .check_shared_food_learning import check, VARIANTS


def extract(path):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    check(data)
    world = data["world"]
    for agent in world["by_agent"]:
        del world["by_agent"][agent]["learning"]
    for episode in world["episodes"]:
        for agent, record in episode["by_agent"].items():
            record["result"] = data["learning"]["by_agent"][agent]["results"][record["request"]["operation_id"]]["result"]
    return {"source_file": path.name, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "frames": data["sensory"]["frames"], "world": world}


if __name__ == "__main__":
    runs = [extract(Path(p)) for p in sys.argv[2:]]
    assert len(runs) == len(VARIANTS) and {r["world"]["scenario"] for r in runs} == set(VARIANTS)
    Path(sys.argv[1]).write_text(json.dumps({"schema": "luanti-l10c-replay-v1",
        "provenance": "Checked real Luanti L10C runs. Accepted frames, observe packets, decisions, factual results "
                      "and World traces are retained; replay remints decision/model IDs after independent canonical review.",
        "runs": runs}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
