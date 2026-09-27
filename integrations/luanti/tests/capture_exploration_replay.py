"""Freeze unmodified L13A observations, World measurements and HTTP wires."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from .check_exploration import check


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("manifest",type=Path)
    parser.add_argument("--output",type=Path,default=Path("tests/fixtures/luanti_l13a_replay.json"))
    args=parser.parse_args()
    paths=[Path(x) for x in json.loads(args.manifest.read_text(encoding="utf-8-sig"))]
    assert len(paths)==len(set(paths))==9
    runs=[];sources=[];summary=[]
    for p in paths:
        raw=p.read_bytes();data=json.loads(raw.decode("utf-8-sig"))
        summary.append(check(data));runs.append(data)
        sources.append(dict(file=p.name,sha256=hashlib.sha256(raw).hexdigest()))
    assert {r["world"]["scenario"] for r in runs}=={
        "straight","right","left","rotated","no_strip","no_food","partial","blocked","faults"}
    by_case={r["world"]["scenario"]:r["world"] for r in runs}
    for key in ("initial_body","food_initial","mountains"):
        left=by_case["right"][key];right=by_case["no_strip"][key]
        if key=="initial_body":
            left={k:v for k,v in left.items() if k!="pose_ref"}
            right={k:v for k,v in right.items() if k!="pose_ref"}
        assert left==right,("strip control",key)
    source_files=[Path(p) for p in ("runtime/exploration.py","runtime/bridge.py","runtime/sensory_observation.py",
        "integrations/luanti/scripts/test-exploration.ps1","integrations/luanti/scripts/install-game.ps1",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/init.lua",
        "integrations/luanti/game/rdl_game/mods/rdl_bridge/distant_sensor.lua",
        "integrations/luanti/tests/check_exploration.py")]
    source_files+=list(Path("integrations/luanti/game/rdl_game/mods/rdl_bridge").glob("exploration*.lua"))
    source_files+=list(Path("integrations/luanti/game/rdl_game/mods/rdl_bridge/textures").glob("rdl_l13_*.png"))
    artifact=dict(schema="l13a-real-luanti-replay-v1",provenance=dict(
        baseline_commit=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
        working_tree_implementation=True,sources=sources,
        source_sha256={p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source_files)},
        method="Unmodified JSON trees and exact HTTP response wires from nine real Luanti runs; World geometry is checker-only.",
        limitations="Fixed color-following rule; kinematic body; sampled mountain surfaces; partial read and callback faults injected; no learning or route memory."),
        summary=summary,runs=runs)
    args.output.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(summary,indent=2))
    print(f"L13A replay saved: {args.output}")


if __name__=="__main__":main()
