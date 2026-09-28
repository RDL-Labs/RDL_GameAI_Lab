"""Post-run field audit; never supplies experimenter data to agents."""
import argparse
import hashlib
import json
import lzma
from collections import Counter
from pathlib import Path


def analyze(report):
    summaries=[]
    for run in report["runs"]:
        data=run["data"];world=data["world"];state=data["runtime"]["exploration"]
        agents={}
        for aid,a in state["agents"].items():
            status=Counter();gates=Counter();applied=0;min_changes=0
            for d in a["decisions"].values():
                meta=d["mb_field"];gates[meta["gate"]]+=1
                assert meta["final_action"]==d["action"] and meta["final_reason"]==d["reason"]
                field=meta["field"]
                if field is None:continue
                status[field["status"]]+=1
                if not field["applied"]:continue
                applied+=1
                t=d["movement_terrain"]
                base={r["direction_deg"]:r["physical"]+r["food"]+r["obstacle"] for r in t["directional_samples"] if r["status"]=="scored"}
                low=min(base.values());minima=[k for k,v in base.items() if abs(v-low)<=1e-9]
                min_changes+=minima!=t["minimum_directions"]
                assert field["model_ref"]==d["model_ref"]
            agents[aid]=dict(status=dict(status),gates=dict(gates),applied=applied,
                terrain_minimum_changes=min_changes,admitted=a["active_model"] is not None,
                model_invalidated=a["learning"]["invalidated"],experience_records=len(a["learning"]["records"]))
        summaries.append(dict(run_id=world["run_id"],mode=state["mb_field_mode"],agents=agents,
            acceptance=run["summary"]["strict_acceptance"],transport_faults=run["summary"]["transport_faults"],
            pickups=run["summary"]["total_pickups"],returns=run["summary"]["total_returns"]))
    return summaries


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("paths",type=Path,nargs="+")
    args=parser.parse_args();out=[]
    for path in args.paths:
        with lzma.open(path,"rt",encoding="utf8") as stream: report=json.load(stream)
        # Current checkout verification is deliberately separate from replay of
        # historical evidence: mismatched versions must be reported, not hidden.
        hashes={k:hashlib.sha256(Path(k).read_bytes()).hexdigest()==v for k,v in report["source_sha256"].items()}
        out.append(dict(artifact=str(path),source_matches=hashes,runs=analyze(report)))
    print(json.dumps(out,indent=2))
