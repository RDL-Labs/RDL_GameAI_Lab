# Compare duplicate parsing with shared parsing; keep full state/output comparisons.
include(joinpath(@__DIR__,"../lw_integrated/native.jl"))
using Test, Statistics
out=abspath(ARGS[1]);mkpath(out)
function view_at(t;hidden=false)
 D("source"=>D("actor"=>"a","observation"=>"ob:$t:a","capture_us"=>t),
   "coverage"=>hidden ? "partial" : "complete",
   "cells"=>[D("angle"=>a,"distance"=>d,"status"=>hidden ? "occluded" : "sampled",
     "appearance"=>hidden ? nothing : a==0 ? "bare_ground" : "grass") for a in ANGLES for d in (1,2,4)])
end
function batch(shared,n)
 s=D("observations"=>0,"counts"=>D(),"records"=>Any[]);m=ground_memory("a")
 for i in 0:n-1
  t=i*1_000_000;v=view_at(t;hidden=i%11==10)
  r=i==0 ? nothing : D("actor"=>"a","source"=>"ob:$(t-1_000_000):a","before_us"=>t-1_000_000,"after_us"=>t,"forward"=>.5,"right"=>0.,"yaw"=>0.)
  if shared
   p=ground_patterns(v);record_ground_patterns!(s,v,p);update_ground!(m,v,r,p)
  else
   record_ground_patterns!(s,v);update_ground!(m,v,r)
  end
 end
 (s,m)
end
@testset "shared ground parsing" begin
 @test batch(false,128)==batch(true,128)
 v=view_at(0);p=ground_patterns(v);saved=deepcopy(p);m=ground_memory("a")
 update_ground!(m,v,nothing,p)
 @test p==saved
 old=deepcopy(m);update_ground!(m,v,nothing,p);@test m==old
 v["source"]["actor"]="other"
 @test_throws ErrorException update_ground!(m,v,nothing,p)
end
batch(false,128);batch(true,128)
samples=Any[]
for i in 1:15, shared in (isodd(i) ? (false,true) : (true,false))
 GC.gc();r=@timed batch(shared,128)
 push!(samples,(shared=shared,seconds=r.time,allocated_bytes=r.bytes,gc_seconds=r.gctime))
end
write(joinpath(out,"measurements.json"),JSON3.write(samples))
for shared in (false,true)
 rows=filter(s->s.shared==shared,samples)
 println((shared=shared,median_seconds=median(s.seconds for s in rows),median_bytes=median(s.allocated_bytes for s in rows)))
end
# Same living loop; replace only its two call sites to reproduce the old path.
path=joinpath(@__DIR__,"../lw_day/run.jl");current=read(path,String)
current=current[first(findfirst("function lw_day(",current)):end]
legacy=replace(current,"patterns=ground_patterns(view)\n                record_ground_patterns!(ground_views[a],view,patterns)"=>"record_ground_patterns!(ground_views[a],view)")
legacy=replace(legacy,"get(ground_receipts,a,nothing),patterns)"=>"get(ground_receipts,a,nothing))")
@test legacy!=current
Base.include_string(@__MODULE__,legacy,path)
native_main([joinpath(out,"old"),"--days","1","--seed","20261005","--food","renewable","--ground","patches","--ground-wear","on","--ground-perception","on","--ground-continuity","on"])
Base.include_string(@__MODULE__,current,path)
native_main([joinpath(out,"shared"),"--spec",joinpath(out,"old/spec.json")])
@test read(joinpath(out,"old/result.json"))==read(joinpath(out,"shared/result.json"))
println("Living outputs byte-identical; call timings include compilation, not a speed comparison.")
