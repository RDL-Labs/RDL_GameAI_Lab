# Offline diagnostic: saved state is read-only, no replay or modified checkpoint.
include(joinpath(@__DIR__,"../../integrations/lightweight_julia/native.jl"))
using Test
input=JSON3.read(read(ARGS[1],String),Dict{String,Any})
output=Dict{String,Any}()
for (actor,s) in input["mb_map"]
 r=s["exploration_relations"]
 before_bytes=sizeof(JSON3.write(r));before_links=length(r["links"])
 totals=Dict(k=>sum(l[k] for l in values(r["links"])) for k in ("support","contradiction","failures","selected"))
 immutable=bytes2hex(sha256(JSON3.write(D("nodes"=>s["nodes"],"edges"=>s["edges"],"chunks"=>s["chunks"]))))
 credits=s["chunk_goal_credits"]
 measured=@timed mb_compress_exploration!(s,91,91*17_280_000_000)
 @test length(r["links"])<=before_links
 @test all(isapprox(sum(l[k] for l in values(r["links"])),v) for (k,v) in totals)
 @test sum(get(l,"represented",1) for l in values(r["links"]))==before_links
 @test credits==s["chunk_goal_credits"]
 @test immutable==bytes2hex(sha256(JSON3.write(D("nodes"=>s["nodes"],"edges"=>s["edges"],"chunks"=>s["chunks"]))))
 output[actor]=D("review"=>measured.value,"relation_bytes_before"=>before_bytes,
  "relation_bytes_after"=>sizeof(JSON3.write(r)),"seconds_including_compilation"=>measured.time,
  "allocated_bytes"=>measured.bytes)
end
write(ARGS[2],JSON3.write(output));println(JSON3.write(output))
