"""Archive exact accepted L14B packets plus explicitly excluded setup attempts."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

from .run_exploration_series import ROOT, OUTPUT, write
from .check_multi_resource import check


def attach_legacy(matrix, path):
    from .check_resource_exploration import check as check_legacy
    legacy=json.loads(gzip.decompress(Path(path).read_bytes()))["runs"][0]
    raw=(OUTPUT/legacy["source"]["file"]).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==legacy["source"]["sha256"]
    assert json.loads(raw.decode("utf-8-sig"))==legacy["data"]
    assert check_legacy(legacy["data"])==legacy["summary"]
    matrix["legacy_regression"]=legacy


def main():
    p=argparse.ArgumentParser();p.add_argument("matrix",type=Path);p.add_argument("output",type=Path)
    p.add_argument("--legacy",type=Path)
    args=p.parse_args();matrix=json.loads(gzip.decompress(args.matrix.read_bytes()))
    for r in matrix["runs"]:
        raw=(OUTPUT/r["source"]["file"]).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==r["source"]["sha256"]
        assert json.loads(raw.decode("utf-8-sig"))==r["data"]
        r["summary"]=check(r["data"])
    # Code that produced behavior must match before acceptance is exported.
    for f,h in matrix["provenance"]["source_sha256"].items():
        assert hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==h,f
    matrix["excluded_attempts"]=[]
    for ident,reason in (
        ("l14b-bb2f919a3e7e4d40","setup failed: one demonstration statue occluded the next agent's specimen"),
        ("l14b-547aa422b3364e0e","setup failed: C specimen was inside the rising ground"),
        ("l14b-c52dc8f24b1f499f","World completed; exporter equality failed on canonical tuple/list JSON normalization")):
        path=OUTPUT/(ident+".snapshot.json");raw=path.read_bytes()
        matrix["excluded_attempts"].append(dict(reason=reason,source=dict(file=path.name,sha256=hashlib.sha256(raw).hexdigest()),
            data=json.loads(raw.decode("utf-8-sig")),acceptance=False))
    if args.legacy:attach_legacy(matrix,args.legacy)
    write(args.output,matrix)
    print(json.dumps(dict(file=str(args.output),bytes=args.output.stat().st_size,
                         sha256=hashlib.sha256(args.output.read_bytes()).hexdigest(),runs=len(matrix["runs"]))))


if __name__=="__main__":main()
