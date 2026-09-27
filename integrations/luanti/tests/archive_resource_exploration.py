"""Verify raw records before archiving L14A acceptance and its rejected trial."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from .run_exploration_series import ROOT, OUTPUT, write
from .check_resource_exploration import check
from .check_exploration import check as check_legacy


def raw_record(path):
    raw=path.read_bytes()
    return json.loads(raw.decode("utf-8-sig")),dict(file=path.name,sha256=hashlib.sha256(raw).hexdigest())


def main():
    p=argparse.ArgumentParser()
    p.add_argument("matrix",type=Path);p.add_argument("legacy",type=Path)
    p.add_argument("rejected",type=Path);p.add_argument("rejected_matrix",type=Path)
    p.add_argument("output",type=Path);a=p.parse_args()
    matrix=json.loads(gzip.decompress(a.matrix.read_bytes()))
    assert len(matrix["runs"])==len(matrix["provenance"]["predeclared"])==3
    for r in matrix["runs"]:
        original,source=raw_record(OUTPUT/r["source"]["file"])
        assert source==r["source"] and original==r["data"]
        assert check(r["data"])==r["summary"]
    matrix["legacy_regression"],legacy_source=raw_record(a.legacy)
    check_legacy(matrix["legacy_regression"])
    rejected,source=raw_record(a.rejected)
    assert any(p["remaining"]>0 and not p["present"] for p in rejected["world"]["final_stock"])
    failed_matrix=json.loads(gzip.decompress(a.rejected_matrix.read_bytes()))
    matrix["rejected_runs"]=[dict(status="rejected_stock_object_loss",data=rejected,source=source,
        provenance=failed_matrix["provenance"],
        reason="The initial long run lost unharvested entities: unchecked default forceload quota and missing negative-elevation blocks.")]
    matrix["provenance"]["legacy_source"]=legacy_source
    matrix["provenance"]["final_source_sha256"]={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest()
        for f in matrix["provenance"]["source_sha256"]}
    matrix["provenance"]["final_source_matches_producer"]=(
        matrix["provenance"]["final_source_sha256"]==matrix["provenance"]["source_sha256"])
    changed=[f for f,h in matrix["provenance"]["source_sha256"].items()
             if h!=matrix["provenance"]["final_source_sha256"][f]]
    assert set(changed)<={"runtime/resource_exploration.py"},"unexpected producer change"
    matrix["provenance"]["post_capture_changes"]=[dict(file=f,
        change="Reject non-object result payload before inventory precheck; all captured valid wire records replay identically with final code.") for f in changed]
    write(a.output,matrix)
    print(json.dumps(dict(file=str(a.output),bytes=a.output.stat().st_size,
        sha256=hashlib.sha256(a.output.read_bytes()).hexdigest()),indent=2))


if __name__=="__main__":main()
