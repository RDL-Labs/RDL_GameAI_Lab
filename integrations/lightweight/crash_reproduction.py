"""Repeat a fixed LW workload in fresh processes; retain failures and host metadata."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time


def write(path, value):
    path.write_text(json.dumps(value, indent=2), encoding='utf8')


def process_memory(pid):
    if os.name != 'nt':
        return None
    from ctypes import wintypes
    class Counters(ctypes.Structure):
        _fields_=[('cb',wintypes.DWORD),('PageFaultCount',wintypes.DWORD)]+[
            (name,ctypes.c_size_t) for name in ('PeakWorkingSetSize','WorkingSetSize',
            'QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage',
            'QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage')]
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    psapi=ctypes.WinDLL('psapi',use_last_error=True)
    kernel.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD]
    kernel.OpenProcess.restype=wintypes.HANDLE
    kernel.CloseHandle.argtypes=[wintypes.HANDLE]
    psapi.GetProcessMemoryInfo.argtypes=[wintypes.HANDLE,ctypes.POINTER(Counters),wintypes.DWORD]
    handle=kernel.OpenProcess(0x0400|0x0010,False,pid)
    if not handle:return None
    try:
        counters=Counters();counters.cb=ctypes.sizeof(counters)
        if not psapi.GetProcessMemoryInfo(handle,ctypes.byref(counters),counters.cb):return None
        return dict(working_set=counters.WorkingSetSize,peak_working_set=counters.PeakWorkingSetSize,
                    private_commit_proxy=counters.PagefileUsage)
    finally:kernel.CloseHandle(handle)


def tail_time(path):
    if not path.exists():return None
    with path.open('rb') as f:
        f.seek(max(0,path.stat().st_size-1_000_000))
        lines=f.read().splitlines()
    values=[]
    for line in lines:
        try:r=json.loads(line)
        except (ValueError,UnicodeError):continue
        values.extend(x for x in (r.get('capture_us'),r.get('ended_us'),
            r.get('result',{}).get('executed_us'),r.get('packet',{}).get('capture_us')) if isinstance(x,int))
    return max(values,default=None)


def worker(root, seconds):
    # Environment is fixed by the parent before any runtime import.
    from .timed_harvest import run
    from .integrated_social_campaign import audit,compact_report
    source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
    options=dict(source['runs']['inherited']['options'],days=1,body_scene='social_base',run_id='lw-scaled-base',
        ground_continuity_enabled=True,exploration_horizon_enabled=True,run_duration_us=seconds*1_000_000)
    write(root/'options.json',options)
    run(root/'run.jsonl',**options)
    write(root/'report.json',compact_report({'scaled':dict(options=options,
        audit=audit(root/'run.jsonl',days=1,duration_us=seconds*1_000_000))}))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--seconds',type=int,default=1800)
    parser.add_argument('--trials',type=int,default=3)
    parser.add_argument('--worker',action='store_true')
    args=parser.parse_args()
    if not 1<=args.seconds<=17280 or not 1<=args.trials<=5:
        parser.error('seconds must be 1..17280 and trials 1..5')
    if args.worker:
        worker(args.output,args.seconds);return
    args.output.mkdir(parents=True,exist_ok=False)
    files=subprocess.check_output(['git','ls-files','runtime','integrations'],text=True).splitlines()
    source_hash=hashlib.sha256()
    for name in sorted(files):
        path=Path(name)
        if path.suffix=='.py':source_hash.update(name.encode()+b'\0'+path.read_bytes())
    metadata=dict(executable=sys.executable,python=sys.version,platform=platform.platform(),
        machine=platform.machine(),commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        source_sha256=source_hash.hexdigest(),seconds=args.seconds,trials=args.trials,
        inherited_environment={k:os.environ.get(k) for k in ('PYTHONHASHSEED','PYTHONPATH','PYTHONHOME','PYTHONMALLOC','PYTHONDEVMODE')},
        fixed_environment=dict(RDL_LW_TIME_PROFILE='human_scale_v1',PYTHONHASHSEED='0'))
    write(args.output/'environment.json',metadata)
    results=[]
    for index in range(args.trials):
        root=args.output/f'trial-{index+1}';root.mkdir()
        env=dict(os.environ,**metadata['fixed_environment'])
        command=[sys.executable,'-X','faulthandler','-m',__spec__.name,'--worker',
                 '--seconds',str(args.seconds),'--output',str(root)]
        start=time.monotonic();peak=0
        with (root/'stdout.log').open('wb') as stdout,(root/'stderr.log').open('wb') as stderr, (root/'memory.jsonl').open('w') as memory:
            process=subprocess.Popen(command,env=env,stdout=stdout,stderr=stderr)
            while process.poll() is None:
                sample=process_memory(process.pid)
                if sample:
                    peak=max(peak,sample['peak_working_set'])
                    memory.write(json.dumps(dict(elapsed=time.monotonic()-start,**sample))+'\n');memory.flush()
                time.sleep(1)
        result=dict(trial=index+1,returncode=process.returncode,exit_hex=hex(process.returncode & 0xffffffff),
            elapsed_seconds=time.monotonic()-start,peak_working_set=peak,
            last_sim_us=tail_time(root/'run.jsonl'),report_written=(root/'report.json').exists())
        write(root/'exit.json',result);results.append(result);write(args.output/'results.json',results)
        print(json.dumps(result),flush=True)
    if any(r['returncode']!=0 or not r['report_written'] for r in results):
        raise SystemExit(1)


if __name__=='__main__':main()
