using JSON3, Test
length(ARGS) in (1,2) || error("OUTPUT [DAYS]")
days=length(ARGS)==2 ? parse(Int,ARGS[2]) : 1
1<=days<=180 || error("days")
repo=normpath(joinpath(@__DIR__,"../.."));root=abspath(ARGS[1]);mkpath(root)
input=JSON3.read(read(joinpath(repo,"outputs/food-age-visual-60d-20261105/input.json"),String),Dict{String,Any})
input["config"]["days"]=days
s=input["scene"];s["reserve"]=fill(0.,4);s["collapse_cognition_gate"]=true
source=joinpath(root,"source");ispath(source) && error("fresh output required")
mkpath(joinpath(source,"integrations"));cp(joinpath(repo,"src"),joinpath(source,"src"));cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(source,"integrations/lightweight_julia"))
write(joinpath(source,"src/data/lw_actor_ids.jl"),"const IDS=(\"npc_a\",\"npc_b\",\"npc_c\",\"npc_d\")\n")
const day_times=Float64[];const previous_wall=Ref(UInt64(0))
function record_collapse_day(day)
 wall=time_ns();push!(day_times,(wall-previous_wall[])/1e9);previous_wall[]=wall
 write(joinpath(root,"progress.json"),JSON3.write(Dict("completed_days"=>day,"target_days"=>days,"wall_seconds_by_day"=>day_times)))
end
p=joinpath(source,"src/lw/simulation/day.jl");code=read(p,String)
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
@assert length(findall(anchor,code))==1
write(p,replace(code,anchor=>anchor*"\n            Main.record_collapse_day(length(daily))"))
write(joinpath(root,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(root,"runner.jl"))
write(joinpath(root,"conditions.json"),JSON3.write(Dict("days"=>days,"actors"=>4,"initial_reserve"=>0,"collapse_cognition_gate"=>true,"checkpoints"=>false,"base"=>"food-age-visual-60d-20261105/input.json","fixed"=>"initial collapse for performance diagnosis; existing training cannot execute while collapsed")))
include(joinpath(source,"integrations/lightweight_julia/native.jl"))
previous_wall[]=time_ns()
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String))
@testset "all-day collapsed actors never observe, decide or consolidate" begin
 for a in (:npc_a,:npc_b,:npc_c,:npc_d)
  @test r.counts[a].collapsed==17280days
  @test sum(values(r.counts[a]))==17280days
  @test r.mb_map[a].observations==0
  @test r.mb_map[a].searches==0
  @test r.final_agents[a].body.reserve==0
  @test r.final_agents[a].position==r.day_starts[1][a].position
 end
 @test r.consumed==0
 @test r.initial_food==r.ground+sum(r.food_resources.waste.counts)+sum(a.inventory+a.personal_stock for a in values(r.final_agents))
end
write(joinpath(root,"completed.json"),JSON3.write(Dict("verified"=>true,"days"=>days,"wall_seconds_by_day"=>day_times)))
