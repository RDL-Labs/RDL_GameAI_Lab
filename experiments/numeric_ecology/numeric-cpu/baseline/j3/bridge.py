"""Linux-only experimental owned-copy bridge; no production imports or fallback."""
import math
import os
from pathlib import Path
import select
import struct
import subprocess
import time

QUERY=struct.Struct('<9d')
VALUE=struct.Struct('<Bd')
REQUEST=struct.Struct('<4sQI')
RESPONSE=struct.Struct('<4sQIQQQQ')
MAX_QUERIES=100000


def encode(queries):
    if len(queries)>MAX_QUERIES:raise ValueError('query_capacity')
    data=bytearray(len(queries)*QUERY.size)
    for i,(kind,s,v,o,m) in enumerate(queries):
        if kind not in ('ray','segment'):raise ValueError('kind')
        QUERY.pack_into(data,i*QUERY.size,kind=='ray',*s,*v,o['x'],o['z'],o['radius'],m)
    return data


def decode(data):
    out=[]
    for tag,value in VALUE.iter_unpack(data):
        if tag==0 and value==0.:out.append(None)
        elif tag in (1,2) and value==0.:out.append(tag==2)
        elif tag==3 and math.isfinite(value) and value>=0.:out.append(value)
        else:raise ValueError('invalid_result')
    return out


def decode_queries(data):
    from experiments.julia_migration.python.reference import prepare
    return [prepare(dict(kind='ray' if k==1. else 'segment' if k==0. else 'invalid',
        start=[sx,sz],vector=[vx,vz],circle=[x,z,r],margin=m))
        for k,sx,sz,vx,vz,x,z,r,m in QUERY.iter_unpack(data)]


def encode_results(values):
    out=bytearray(len(values)*VALUE.size)
    for i,v in enumerate(values):
        tag=0 if v is None else (2 if v else 1) if isinstance(v,bool) else 3
        VALUE.pack_into(out,i*VALUE.size,tag,float(v) if tag==3 else 0.)
    return out


class Bridge:
    def __init__(self, stderr, executable='julia', timeout=30):
        self.timeout=timeout;self.sequence=0;self.failed=False
        project=Path('experiments/julia_migration/julia').resolve()
        script=Path('experiments/julia_migration/j3/server.jl').resolve()
        self.process=subprocess.Popen([executable,'--startup-file=no','--threads=1',
            f'--project={project}',str(script)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,
            stderr=stderr,bufsize=0)
        try:
            if self._read(12,time.monotonic()+timeout)!=b'RDLJ3_READY\n':raise ValueError('server_handshake')
        except BaseException:
            self.close();raise

    def _read(self,n,deadline):
        data=bytearray()
        while len(data)<n:
            remaining=deadline-time.monotonic()
            if remaining<=0 or not select.select([self.process.stdout],[],[],remaining)[0]:raise TimeoutError('bridge_read')
            chunk=os.read(self.process.stdout.fileno(),n-len(data))
            if not chunk:raise RuntimeError('server_eof')
            data.extend(chunk)
        return data

    def _write(self,data,deadline):
        view=memoryview(data)
        while view:
            remaining=deadline-time.monotonic()
            if remaining<=0 or not select.select([],[self.process.stdin],[],remaining)[1]:raise TimeoutError('bridge_write')
            written=os.write(self.process.stdin.fileno(),view)
            view=view[written:]

    def call(self,queries):
        if self.failed:raise RuntimeError('bridge_failed')
        start=time.perf_counter_ns()
        payload=encode(queries)
        packed=time.perf_counter_ns()
        self.sequence+=1;deadline=time.monotonic()+self.timeout
        try:
            self._write(REQUEST.pack(b'RDL3',self.sequence,len(queries)),deadline)
            self._write(payload,deadline)
            magic,seq,n,conversion,kernel,allocated,gc=RESPONSE.unpack(self._read(RESPONSE.size,deadline))
            if magic!=b'RDR3' or seq!=self.sequence or n!=len(queries):raise ValueError('response_binding')
            result=self._read(n*VALUE.size,deadline)
            received=time.perf_counter_ns()
            values=decode(result)
        except BaseException:
            self.failed=True
            raise
        end=time.perf_counter_ns()
        return values,dict(total_ns=end-start,packing_ns=packed-start,roundtrip_ns=received-packed,
            decoding_ns=end-received,server_conversion_ns=conversion,server_kernel_ns=kernel,
            server_allocated_bytes=allocated,server_gc_ns=gc,server_pid=self.process.pid)

    def close(self):
        p=self.process
        if p.stdin and not p.stdin.closed:p.stdin.close()
        try:p.wait(timeout=5)
        except subprocess.TimeoutExpired:p.kill();p.wait()
        if p.stdout and not p.stdout.closed:p.stdout.close()


def difference(expected,actual):
    if len(expected)!=len(actual):return dict(reason='length')
    for i,(a,b) in enumerate(zip(expected,actual)):
        if a is None:ok=b is None
        elif isinstance(a,bool):ok=type(b) is bool and a==b
        else:ok=type(b) in (int,float) and math.isfinite(b) and abs(a-b)<=1e-12+1e-12*abs(a)
        if not ok:return dict(index=i,expected=a,actual=b)
    return None


def shadow(queries,bridge):
    from experiments.julia_migration.python.reference import batch
    expected=batch(queries)
    actual,timing=bridge.call(queries)
    mismatch=difference(expected,actual)
    if mismatch:raise ValueError(('shadow_mismatch',mismatch))
    return expected,timing
