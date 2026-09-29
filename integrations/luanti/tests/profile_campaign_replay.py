"""Offline profiling of identical recorded requests, with passive GC callbacks.

Extraction is a separate process so the original World/Runtime object graph does
not remain in the collector during replay. No GC policy or thresholds are changed.
"""
import argparse
from collections import deque
from functools import wraps
import gc
import gzip
import hashlib
import json
import lzma
from pathlib import Path
from time import perf_counter_ns


def extract(source, destination):
    with lzma.open(source,"rt",encoding="utf8") as stream: report=json.load(stream)
    data=report["runs"][0]["data"];s=data["runtime"]["exploration"];w=data["world"]
    header=dict(run_id=w["run_id"],periods=s["periods"],mb_field_mode=s["mb_field_mode"],
                harvest_state=True,agent_count=s.get("agent_count",3),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
    with gzip.open(destination,"wt",encoding="utf8",compresslevel=1) as out:
        out.write(json.dumps(header)+"\n")
        for e in w["deliveries"]:
            out.write(json.dumps([e["kind"],e["request"],json.loads(e["response_wire"])],separators=(",",":"))+"\n")
    print("extracted",len(w["deliveries"]),flush=True)


class Profile:
    def __init__(self):
        self.phase="outside_call";self.call=None;self.stats={};self.gc_stats={};self.gc_start={};self.slow=deque(maxlen=128)
    def add(self,table,key,elapsed):
        s=table.setdefault(key,dict(count=0,total_us=0,max_us=0));s["count"]+=1;s["total_us"]+=elapsed;s["max_us"]=max(s["max_us"],elapsed)
    def collection(self,phase,info):
        generation=info["generation"]
        if phase=="start":self.gc_start[generation]=perf_counter_ns()
        elif generation in self.gc_start:
            us=(perf_counter_ns()-self.gc_start.pop(generation))//1000
            self.add(self.gc_stats,str(generation),us)
            if self.call is not None:self.call["gc_us"]+=us
            if us>=100000:self.slow.append(dict(type="gc",generation=generation,phase=self.phase,elapsed_us=us,call=dict(self.call) if self.call else None))
    def wrap(self,owner,name,label):
        original=getattr(owner,name)
        @wraps(original)
        def measured(*args,**kwargs):
            old=self.phase;self.phase=label;start=perf_counter_ns()
            try:return original(*args,**kwargs)
            finally:
                self.add(self.stats,label,(perf_counter_ns()-start)//1000);self.phase=old
        setattr(owner,name,measured)
        return lambda:setattr(owner,name,original)


def replay(path, output):
    from runtime.landmark_return_campaign import ReturnCampaign, CampaignAgent
    from runtime.landmark_day_cycle import DayCycleAgent
    from runtime.multi_resource_exploration import PredictableResourceAgent
    import runtime.landmark_day_cycle as day_module
    import runtime.multi_resource_exploration as multi_module
    import runtime.landmark_return_campaign as campaign_module
    p=Profile();restores=[]
    for owner,name,label in [(PredictableResourceAgent,"_advance","advance"),(DayCycleAgent,"_decision","day_decision"),
        (CampaignAgent,"_stage_sensory_store","sensory_stage"),(day_module,"deepcopy","day_deepcopy"),
        (multi_module,"deepcopy","storage_deepcopy"),(campaign_module,"deepcopy","campaign_deepcopy")]:
        restores.append(p.wrap(owner,name,label))
    thresholds=gc.get_threshold();gc.callbacks.append(p.collection)
    started=perf_counter_ns();count=0
    try:
        with gzip.open(path,"rt",encoding="utf8") as stream:
            header=json.loads(next(stream));loop=ReturnCampaign(**{k:v for k,v in header.items() if k!="source_sha256"})
            for line in stream:
                kind,request,expected=json.loads(line)
                capture=request.get("capture_us",request.get("executed_us",0))
                p.call=dict(kind=kind,agent=request["agent_id"],capture_us=capture,gc_us=0)
                p.phase=kind;before=perf_counter_ns()
                actual=getattr(loop,kind)(request)
                elapsed=(perf_counter_ns()-before)//1000
                p.add(p.stats,kind,elapsed)
                if elapsed>=100000:p.slow.append(dict(type="call",elapsed_us=elapsed,**p.call))
                p.call=None;p.phase="outside_call"
                assert actual==expected,(count,kind)
                count+=1
                if count%10000==0:print("replayed",count,flush=True)
    finally:
        elapsed_us=(perf_counter_ns()-started)//1000
        gc.callbacks.remove(p.collection)
        for restore in reversed(restores):restore()
    assert gc.get_threshold()==thresholds
    result=dict(schema="campaign-offline-profile-v1",header=header,responses_verified=count,elapsed_us=elapsed_us,
                gc_thresholds=thresholds,stats=p.stats,gc=p.gc_stats,slow=list(p.slow),state_hashes={},night_storage={})
    # Outside measured loop. Public snapshot values, not internal sharing identities.
    encoder=json.JSONEncoder(sort_keys=True,separators=(",",":"),ensure_ascii=False,allow_nan=False)
    for aid,agent in loop.agents.items():
        nights=[n for d in agent.decisions.values() for n in d["day_cycle"]["nights"]]
        result["night_storage"][aid]=dict(references=len(nights),distinct_entries=len({id(n) for n in nights}))
        state=agent.snapshot();h=hashlib.sha256()
        for chunk in encoder.iterencode(state):h.update(chunk.encode("utf8"))
        result["state_hashes"][aid]=h.hexdigest();del state,nights
    result["source_sha256"]={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in (
        "runtime/landmark_day_cycle.py","runtime/landmark_return_campaign.py","runtime/multi_resource_exploration.py","runtime/resource_exploration.py")}
    output.write_text(json.dumps(result,indent=2)+"\n",encoding="utf8")
    print(json.dumps(dict(responses=count,elapsed_us=elapsed_us,gc=p.gc_stats,stats=p.stats)),flush=True)


if __name__=="__main__":
    a=argparse.ArgumentParser();a.add_argument("mode",choices=("extract","replay"));a.add_argument("source",type=Path);a.add_argument("output",type=Path)
    args=a.parse_args()
    (extract if args.mode=="extract" else replay)(args.source,args.output)
