# Execution-only optional geometry cache. CPU is default; does not sample RNG or grass.
include("neighbor_opencl.jl")
const RABBIT_NEIGHBOR_BACKEND=Ref{Any}(nothing)
# Conservative Float32 ambiguity band, map units; validate against Float64 in audit mode.
const RABBIT_NEIGHBOR_GPU_BAND=.001
mutable struct RabbitNeighborBatch
 gpu::RabbitNeighborOpenCL.Backend
 world::World
 obstacles::Vector{RDLMigrationProbe.Circle}
 queries::Matrix{Float32};gaps::Vector{Float32}
 slots::Dict{Tuple{Int,Int},Int};origins::Dict{Int,Tuple{Float64,Float64}}
 tick::Int;audit::Bool;batches::Int;queries_total::Int;hits::Int;fallbacks::Int
end
function enable_rabbit_neighbor_gpu!(w;audit=false)
 disable_rabbit_neighbor_gpu!()
 # Large coordinates are outside the validated Float32 guard envelope.
 maximum(abs, (w.xmin,w.xmax,w.zmin,w.zmax))<=1000 || error("GPU map extent exceeds validated envelope")
 all(o->max(abs(o.x),abs(o.z),abs(o.radius))<=1000,w.obstacles) || error("GPU obstacle extent")
 b=RabbitNeighborBatch(RabbitNeighborOpenCL.Backend(w),w,copy(w.obstacles),zeros(Float32,4,0),Float32[],Dict(),Dict(),-1,audit,0,0,0,0)
 RABBIT_NEIGHBOR_BACKEND[]=b;b
end
function disable_rabbit_neighbor_gpu!()
 b=RABBIT_NEIGHBOR_BACKEND[]
 b!==nothing && RabbitNeighborOpenCL.close!(b.gpu)
 RABBIT_NEIGHBOR_BACKEND[]=nothing
end
rabbit_neighbor_stats()=let b=RABBIT_NEIGHBOR_BACKEND[]
 b===nothing ? nothing : (device=b.gpu.device,batches=b.batches,queries=b.queries_total,hits=b.hits,fallbacks=b.fallbacks,audit=b.audit)
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
 empty!(b.slots);empty!(b.origins);b.tick=t;n=length(a.x)
 if length(b.gaps)<8n;b.queries=zeros(Float32,4,8n);b.gaps=zeros(Float32,8n);end
 used=0
 for i in 1:n
  alive!==nothing && !alive[i] && continue
  a.state[i]==SEARCH && rabbit_needs_neighbors(policy,a,i,t,overrides) || continue
  p=(a.x[i],a.z[i]);b.origins[i]=p;k=cell(w,p...);ix=mod(k-1,w.nx)+1;iz=div(k-1,w.nx)+1
  for (dx,dz) in OFFSETS
   jx,jz=ix+dx,iz+dz
   1<=jx<=w.nx && 1<=jz<=w.nz || continue
   j=jx+(jz-1)*w.nx;w.walkable[j] || continue;q=center(w,j)
   used+=1;b.slots[(i,j)]=used
   b.queries[1,used]=p[1];b.queries[2,used]=p[2];b.queries[3,used]=q[1];b.queries[4,used]=q[2]
  end
 end
 used==0 && return
 RabbitNeighborOpenCL.evaluate!(b.gpu,b.queries,b.gaps,used);b.batches+=1;b.queries_total+=used
end
function rabbit_neighbor_clear(w,a,i,j,t,p,q)
 b=RABBIT_NEIGHBOR_BACKEND[]
 b===nothing && return clear(w,p,q)
 slot=b.tick==t && get(b.origins,i,nothing)==p ? get(b.slots,(i,j),0) : 0
 slot==0 && return clear(w,p,q)
 gap=b.gaps[slot]
 if !isfinite(gap) || abs(gap)<=RABBIT_NEIGHBOR_GPU_BAND
  b.fallbacks+=1;return clear(w,p,q)
 end
 answer=w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25 &&
  material(w.phase,q...)!=WATER && material(w.phase,(p[1]+q[1])/2,(p[2]+q[2])/2)!=WATER && gap>0
 b.audit && answer!=clear(w,p,q) && error("GPU/CPU neighbor geometry mismatch")
 b.hits+=1;answer
end
