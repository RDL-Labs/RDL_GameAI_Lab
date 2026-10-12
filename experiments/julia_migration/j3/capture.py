"""Observe Python-owned geometry calls; always return original results."""
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
from .bridge import encode,encode_results,MAX_QUERIES


def save(path,value):path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf8')


@contextmanager
def capture_calls(root):
    from integrations.lightweight import world
    from integrations.lightweight.social_life import SocialWorld
    originals={'ray_hit':world.ray_hit,'segment_hit':world.segment_hit}
    packet=SocialWorld.packet;active=None;snapshots=[];patched=[]
    def ray(start,direction,obj):
        result=originals['ray_hit'](start,direction,obj)
        record('ray',start,direction,obj,0.,result)
        return result
    def segment(start,end,obj,margin=0):
        result=originals['segment_hit'](start,end,obj,margin)
        record('segment',start,end,obj,margin,result)
        return result
    wrappers={'ray_hit':ray,'segment_hit':segment}
    def record(kind,start,vector,obj,margin,result):
        if active is None:return
        if len(active['queries'])>=MAX_QUERIES:raise ValueError('snapshot_capacity')
        active['queries'].append((kind,tuple(start),tuple(vector),
            {k:obj[k] for k in ('x','z','radius')},margin))
        active['expected'].append(result)
    def observed_packet(self,aid,slot):
        nonlocal active
        selected=slot*250000 in (0,60_000_000,120_000_000)
        active=dict(queries=[],expected=[]) if selected else None
        try:
            p=packet(self,aid,slot)
            if selected:
                key=f'{aid}-{p["capture_us"]}'
                data=encode(active['queries']);expected=encode_results(active['expected'])
                (root/(key+'.queries.bin')).write_bytes(data)
                (root/(key+'.expected.bin')).write_bytes(expected)
                snapshots.append(dict(key=key,query_count=len(active['queries']),
                    ray_count=sum(q[0]=='ray' for q in active['queries']),
                    binding={k:p[k] for k in ('run_id','agent_id','observation_id','capture_us','pose_ref')},
                    input_sha256=hashlib.sha256(data).hexdigest(),expected_sha256=hashlib.sha256(expected).hexdigest(),
                    packet_sha256=hashlib.sha256(json.dumps(p,sort_keys=True).encode()).hexdigest()))
            return p
        finally:active=None
    # Existing aliases, plus future imports of these replaced world attributes.
    for module in list(sys.modules.values()):
        if module is None:continue
        for name,original in originals.items():
            if vars(module).get(name) is original:
                setattr(module,name,wrappers[name]);patched.append(module.__name__+'.'+name)
    SocialWorld.packet=observed_packet
    try:yield snapshots,patched
    finally:
        SocialWorld.packet=packet
        for module in list(sys.modules.values()):
            if module is None:continue
            for name,wrapper in wrappers.items():
                if vars(module).get(name) is wrapper:setattr(module,name,originals[name])


def main(root):
    from integrations.lightweight.timed_harvest import run
    root.mkdir(parents=True,exist_ok=False)
    source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text())
    options=dict(source['runs']['inherited']['options'],days=1,body_scene='social_base',
        run_id='lw-scaled-base',ground_continuity_enabled=True,exploration_horizon_enabled=True,
        observation_interval_us=1_000_000,movement_inertia=True,log_mode='off',run_duration_us=180_000_000)
    baseline=run(root/'unused-baseline.jsonl',**options)
    with capture_calls(root) as (snapshots,patched):
        observed=run(root/'unused-capture.jsonl',**options)
    save(root/'baseline_summary.json',baseline);save(root/'observed_summary.json',observed)
    bt=baseline.pop('elapsed_seconds');ot=observed.pop('elapsed_seconds')
    save(root/'manifest.json',dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        python=sys.version,platform=platform.platform(),cpu=Path('/proc/cpuinfo').read_text(),options=options,
        final_state_equal=baseline==observed,baseline_seconds=bt,instrumented_seconds=ot,
        exclusion_allowlist=['elapsed_seconds'],patched_aliases=patched,snapshots=snapshots,
        authority='Python-only; original primitive and packet results returned'))
    assert baseline==observed
    assert len(snapshots)==9


if __name__=='__main__':main(Path(sys.argv[1]))
