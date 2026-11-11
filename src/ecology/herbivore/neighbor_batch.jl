# Execution-only optional geometry cache. CPU is default; does not sample RNG or grass.
include("neighbor_opencl.jl")
# Conservative Float32 ambiguity band, map units; validate against Float64 in audit mode.
const RABBIT_NEIGHBOR_GPU_BAND=.001
# Provisional execution threshold: candidate count per batch, >=128 uses GPU.
# Based on the 30-day workload, not a measured universal crossover.
const RABBIT_NEIGHBOR_GPU_MIN_QUERIES=128
mutable struct RabbitNeighborBatch
 gpu::Union{Nothing,RabbitNeighborOpenCL.Backend}
 world::World
 obstacles::Vector{RDLMigrationProbe.Circle}
 queries::Matrix{Float64};gpu_queries::Matrix{Float32};gaps::Vector{Float32};clear_results::Vector{Bool}
 slots::Matrix{Int};origins::Matrix{Float64}
 automatic::Bool;gpu_min_queries::Int;cpu_batches::Int;gpu_batches::Int;cpu_queries::Int;gpu_queries_total::Int
 tick::Int;audit::Bool;batches::Int;queries_total::Int;hits::Int;fallbacks::Int
end
const RABBIT_NEIGHBOR_BACKEND=Ref{Union{Nothing,RabbitNeighborBatch}}(nothing)
function enable_rabbit_neighbor_batch!(w;gpu=false,audit=false,automatic=false,gpu_min_queries=RABBIT_NEIGHBOR_GPU_MIN_QUERIES)
 gpu_min_queries>0 || error("positive GPU threshold required")
 automatic && !gpu && error("automatic mode requires GPU backend")
 disable_rabbit_neighbor_gpu!()
 # Large coordinates are outside the validated Float32 guard envelope.
 if gpu
  maximum(abs, (w.xmin,w.xmax,w.zmin,w.zmax))<=1000 || error("GPU map extent exceeds validated envelope")
  all(o->max(abs(o.x),abs(o.z),abs(o.radius))<=1000,w.obstacles) || error("GPU obstacle extent")
 end
 b=RabbitNeighborBatch(gpu ? RabbitNeighborOpenCL.Backend(w) : nothing,w,copy(w.obstacles),zeros(4,0),zeros(Float32,4,0),Float32[],Bool[],zeros(Int,9,0),zeros(2,0),automatic,gpu_min_queries,0,0,0,0,-1,audit,0,0,0,0)
 RABBIT_NEIGHBOR_BACKEND[]=b;b
end
enable_rabbit_neighbor_gpu!(w;audit=false)=enable_rabbit_neighbor_batch!(w;gpu=true,audit)
function disable_rabbit_neighbor_gpu!()
 b=RABBIT_NEIGHBOR_BACKEND[]
 b!==nothing && b.gpu!==nothing && RabbitNeighborOpenCL.close!(b.gpu)
 RABBIT_NEIGHBOR_BACKEND[]=nothing
end
rabbit_neighbor_stats()=let b=RABBIT_NEIGHBOR_BACKEND[]
 b===nothing ? nothing : (device=b.gpu===nothing ? "CPU common batch" : b.gpu.device,automatic=b.automatic,gpu_min_queries=b.gpu_min_queries,cpu_batches=b.cpu_batches,gpu_batches=b.gpu_batches,cpu_queries=b.cpu_queries,gpu_queries=b.gpu_queries_total,batches=b.batches,queries=b.queries_total,hits=b.hits,fallbacks=b.fallbacks,audit=b.audit)
end
function rabbit_needs_neighbors(policy,a,i,t,overrides)
 overrides!==nothing && overrides[i]!=0 && return false
 if policy isa RabbitSwimmingPolicy
  haskey(policy.trips,i) && return false
  mod(t+i,RABBIT_SWIMMING.interval)==0 && return true
  policy=policy.base
 end
 (t>=a.next_sense[i] || a.target[i]==0) || return false
 if policy isa RabbitApproachPolicy
  m=get(policy.actors,i,nothing)
  m!==nothing && m.target!=0 && return false
 end
 true
end
function prepare_rabbit_neighbor_batch!(w,a,t,policy,alive,overrides)
 b=RABBIT_NEIGHBOR_BACKEND[];b===nothing && return
 b.world===w || error("GPU backend belongs to a different world")
 w.obstacles==b.obstacles || error("GPU static obstacle geometry changed; rebuild backend")
 b.tick=t;n=length(a.x)
 if size(b.slots,2)<n
  b.queries=zeros(4,8n);b.gpu_queries=zeros(Float32,4,8n);b.gaps=zeros(Float32,8n);b.clear_results=zeros(Bool,8n)
  b.slots=zeros(Int,9,n);b.origins=zeros(2,n)
 end
 fill!(b.slots,0)
 used=0
 for i in 1:n
  alive!==nothing && !alive[i] && continue
  a.state[i]==SEARCH && rabbit_needs_neighbors(policy,a,i,t,overrides) || continue
  p=(a.x[i],a.z[i]);b.origins[1,i]=p[1];b.origins[2,i]=p[2];k=cell(w,p...);ix=mod(k-1,w.nx)+1;iz=div(k-1,w.nx)+1
  for (dx,dz) in OFFSETS
   jx,jz=ix+dx,iz+dz
   1<=jx<=w.nx && 1<=jz<=w.nz || continue
   j=jx+(jz-1)*w.nx;w.walkable[j] || continue;q=center(w,j)
   used+=1;b.slots[(dx+1)*3+dz+2,i]=used
   b.queries[1,used]=p[1];b.queries[2,used]=p[2];b.queries[3,used]=q[1];b.queries[4,used]=q[2]
  end
 end
 used==0 && return
 evaluate_rabbit_neighbors!(b,used);b.batches+=1;b.queries_total+=used
end
function evaluate_rabbit_neighbors!(b,used)
 use_gpu=b.gpu!==nothing && (!b.automatic || used>=b.gpu_min_queries)
 if use_gpu
  b.gpu_batches+=1;b.gpu_queries_total+=used
 else
  b.cpu_batches+=1;b.cpu_queries+=used
 end
 if use_gpu
  @inbounds for j in 1:used, k in 1:4;b.gpu_queries[k,j]=b.queries[k,j];end
  RabbitNeighborOpenCL.evaluate!(b.gpu,b.gpu_queries,b.gaps,used)
 end
 @inbounds for j in 1:used
  p=(b.queries[1,j],b.queries[2,j]);q=(b.queries[3,j],b.queries[4,j])
  if !use_gpu
   b.clear_results[j]=!any(o->RDLMigrationProbe.segment_hit(p,q,o,.25),b.obstacles)
  else
   gap=b.gaps[j]
   if !isfinite(gap) || abs(gap)<=RABBIT_NEIGHBOR_GPU_BAND
    b.fallbacks+=1
    b.clear_results[j]=!any(o->RDLMigrationProbe.segment_hit(p,q,o,.25),b.obstacles)
   else
    b.clear_results[j]=gap>0
   end
  end
 end
end
function rabbit_neighbor_clear(w,a,i,j,t,p,q)
 b=RABBIT_NEIGHBOR_BACKEND[]
 b===nothing && return clear(w,p,q)
 slot=0
 if b.tick==t && i<=size(b.slots,2) && b.origins[1,i]==p[1] && b.origins[2,i]==p[2]
  k=cell(w,p...);dx=mod(j-1,w.nx)-mod(k-1,w.nx);dz=div(j-1,w.nx)-div(k-1,w.nx)
  if -1<=dx<=1 && -1<=dz<=1;slot=b.slots[(dx+1)*3+dz+2,i];end
 end
 slot==0 && return clear(w,p,q)
 answer=w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25 &&
  (RABBIT_TERRAIN.enabled || (material(w.phase,q...)!=WATER && material(w.phase,(p[1]+q[1])/2,(p[2]+q[2])/2)!=WATER)) && b.clear_results[slot]
 b.audit && answer!=clear(w,p,q) && error("GPU/CPU neighbor geometry mismatch")
 b.hits+=1;answer
end
