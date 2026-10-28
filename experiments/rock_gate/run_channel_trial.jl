# Frozen-input fresh-cohort run with observational join diagnostics.
using JSON3, Test, SHA
const repo=normpath(joinpath(@__DIR__,"../.."))
const original=abspath(ARGS[1]);const out=abspath(ARGS[2]);const days=parse(Int,ARGS[3])
@assert 1<=days<=90
ispath(out) && error("fresh output required")
mkpath(out);const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
cp(@__FILE__,joinpath(out,"runner.jl"))
input=JSON3.read(read(original,String),Dict{String,Any});old_days=input["config"]["days"]
input["config"]["days"]=days
caseout=joinpath(out,"ordinary");mkpath(caseout)
specpath=joinpath(caseout,"input.json");write(specpath,JSON3.write(input))
@test merge(input["config"],Dict("days"=>old_days))==JSON3.read(read(original,String),Dict{String,Any})["config"]
@test all(!f["renewable"] for f in input["scene"]["food"])
write(joinpath(out,"input-origin.json"),JSON3.write(Dict("path"=>original,"sha256"=>bytes2hex(sha256(read(original))),"changed"=>Dict("days"=>[old_days,days]),"fresh_cohort"=>true)))
const counts=Dict(a=>Dict("join_proposals"=>0,"join_recognized"=>0,"remembered_edges_reused"=>0) for a in ("npc_a","npc_b","npc_c"))
const events=Any[];const positions=Any[];const started=Ref(time());const daily=Any[]
function channel_candidate_probe!(s,out,now)
 for p in out
  haskey(p,"mb_join") || continue
  counts[s["actor"]]["join_proposals"]+=1
  counts[s["actor"]]["remembered_edges_reused"]+=length(p["mb_path"])-p["mb_join"]["bridge_length"]
 end
end
function channel_join_probe!(s,a,now)
 counts[s["actor"]]["join_recognized"]+=1
 push!(events,Dict("actor"=>s["actor"],"us"=>now,"route"=>a["id"],"join"=>deepcopy(a["join"])))
 length(events)>256 && popfirst!(events)
end
function channel_tick!(sec,w,home)
 if mod(sec+1,60)==0
  for a in keys(w.positions)
   push!(positions,(sec=sec+1,actor=a,position=w.positions[a],reserve=w.bodies[a].reserve))
  end
 end
 if mod(sec+1,17280)==0
  day=div(sec+1,17280)
  push!(daily,Dict("day"=>day,"elapsed_seconds"=>time()-started[],"counts"=>deepcopy(counts)))
  write(joinpath(out,"join-diagnostics.json"),JSON3.write(Dict("totals"=>counts,"daily"=>daily,"recent_recognitions"=>events)))
  write(joinpath(caseout,"positions.json"),JSON3.write(positions))
  println("DAY $day elapsed=$(round(time()-started[],digits=1))s joins=$(sum(v["join_recognized"] for v in values(counts)))");flush(stdout)
 end
end
function patch_saved(relative,anchor,replacement)
 path=joinpath(snapshot,relative);source=read(path,String);@assert count(anchor,source)==1
 write(path,replace(source,anchor=>replacement))
end
patch_saved("src/lw/simulation/day.jl","        advance_physiology!(w,metabolism,guts,food_body)","        advance_physiology!(w,metabolism,guts,food_body)\n        Main.channel_tick!(sec,w,spec.home)")
patch_saved("src/lw/learning/mb_map.jl","    s[\"expanded\"]+=expanded;s[\"proposals\"]+=length(out)","    s[\"expanded\"]+=expanded;s[\"proposals\"]+=length(out)\n    Main.channel_candidate_probe!(s,out,now)")
patch_saved("src/lw/learning/mb_routes.jl","    a[\"chunk\"]=join[\"chunk\"];a[\"chunk_start_index\"]=join[\"index\"];a[\"chunk_path_offset\"]=join[\"bridge_length\"]","    a[\"chunk\"]=join[\"chunk\"];a[\"chunk_start_index\"]=join[\"index\"];a[\"chunk_path_offset\"]=join[\"bridge_length\"]\n    Main.channel_join_probe!(s,a,now)")
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
started[]=time()
native_main([joinpath(caseout,"run"),"--spec",specpath,"--checkpoint-dir",joinpath(caseout,"checkpoints")])
r=JSON3.read(read(joinpath(caseout,"run/result.json"),String))
@testset "channel trial life invariants" begin
 @test length(r.daily)==days
 for (i,d) in enumerate(r.daily)
  @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(s.inventory+s.personal_stock for s in values(d.physical))
  @test d.replenished_food==0
  i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
 end
end
write(joinpath(out,"completed.json"),JSON3.write(Dict("days"=>days,"join_counts"=>counts,"recent_recognitions"=>events)))
