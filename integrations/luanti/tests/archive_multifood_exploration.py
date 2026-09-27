"""Verify original snapshots and save L13W replay plus old single-Food regression."""
import gzip
import hashlib
import json
from pathlib import Path
from .run_exploration_series import ROOT, OUTPUT, write
from .check_learned_exploration import check_matrix
from .check_exploration import check


def archive(matrix,legacy,destination):
    a=json.loads(gzip.decompress(Path(matrix).read_bytes()))
    assert len(a["series"])==2
    sources={}
    for s in a["series"]:
        for d in s["days"]:
            raw=(OUTPUT/d["source"]["file"]).read_bytes()
            assert hashlib.sha256(raw).hexdigest()==d["source"]["sha256"]
            assert json.loads(raw.decode("utf-8-sig"))==d["data"]
            assert d["source"]["file"] not in sources
            sources[d["source"]["file"]]=d["source"]["sha256"]
    raw=Path(legacy).read_bytes();a["legacy_regression"]=json.loads(raw.decode("utf-8-sig"))
    a["provenance"]["legacy_source"]=dict(file=Path(legacy).name,sha256=hashlib.sha256(raw).hexdigest())
    a["provenance"]["verified_snapshot_sha256"]=sources
    a["provenance"]["final_source_sha256"]={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in a["provenance"]["source_sha256"]}
    a["validation_history"]=["Initial boot l13s-02371463518541fc failed before observation: new Lua module was absent from the installer copy list. Installer fixed, same sites/seed/limits retained.",
                             "No World snapshot was rewritten. Exact final-code wire and learning-state replay, plus independent acquisition/body audits, passed."]
    check_matrix(a);check(a["legacy_regression"]);write(Path(destination),a)
    print(json.dumps(dict(world_runs=len(sources),bytes=Path(destination).stat().st_size,
                         sha256=hashlib.sha256(Path(destination).read_bytes()).hexdigest())))


if __name__=="__main__":
    import sys
    archive(*sys.argv[1:])
