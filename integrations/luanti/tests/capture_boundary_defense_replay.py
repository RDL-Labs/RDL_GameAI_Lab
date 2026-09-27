"""Freeze unmodified L11 requests, receipts and World evidence after checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from .check_boundary_defense import check


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("manifest",type=Path)
    parser.add_argument("--output",type=Path,default=Path("tests/fixtures/luanti_l11_replay.json"))
    args=parser.parse_args()
    paths=[Path(p) for p in json.loads(args.manifest.read_text(encoding="utf-8-sig"))]
    assert len(paths)==26 and len(set(paths))==26
    runs=[];sources=[]
    for path in paths:
        raw=path.read_bytes();data=json.loads(raw.decode("utf-8-sig"));check(data)
        runs.append(data)
        sources.append({"file":path.name,"sha256":hashlib.sha256(raw).hexdigest()})
    source_files=[Path("runtime/boundary_defense.py"),Path("runtime/bridge.py")]
    source_files+=list(Path("integrations/luanti/game/rdl_game/mods/rdl_bridge").glob("boundary_defense*.lua"))
    artifact={"schema":"l11-real-luanti-replay-v1","provenance":{
        "baseline_commit":subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip(),
        "working_tree_implementation":True,"sources":sources,
        "source_sha256":{p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source_files)},
        "method":"Unmodified JSON trees and exact HTTP response wires; instrumented pickup adapter; no general visual action recognition.",
        "world_evidence_not_runtime_input":True},"runs":runs}
    args.output.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"L11 frozen replay: {args.output} ({len(runs)} runs)")


if __name__=="__main__":main()
