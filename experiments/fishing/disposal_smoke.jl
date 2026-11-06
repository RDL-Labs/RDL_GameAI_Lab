using JSON3, Test
repo=normpath(joinpath(@__DIR__,"../.."))
root=abspath(ARGS[1]);mkpath(root)
input=JSON3.read(read(joinpath(repo,"outputs/salted-fish-abundant-30d-20261105/input.json"),String),Dict{String,Any})
s=input["scene"];input["config"]["days"]=1
s["configured_fishing_training"]=false;s["configured_salted_fish_sample"]=false
s["initial_personal_stock"]=fill(8,4)
s["initial_personal_food_counts"]=Dict(a=>[5,0,0,0,0,2,0,1] for a in ("npc_a","npc_b","npc_c","npc_d"))
push!(s["food_facilities"],Dict("id"=>2,"name"=>"camp_waste_bin","x"=>.8,"z"=>6.,"height"=>.6,"radius"=>.4,"work_radius"=>2.1,"color"=>"grey","processing_kinds"=>Int[],"accepts_waste"=>true))
source=joinpath(root,"source");ispath(source) && error("fresh output required")
mkpath(joinpath(source,"integrations"));cp(joinpath(repo,"src"),joinpath(source,"src"));cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(source,"integrations/lightweight_julia"))
write(joinpath(source,"src/data/lw_actor_ids.jl"),"const IDS=(\"npc_a\",\"npc_b\",\"npc_c\",\"npc_d\")\n")
write(joinpath(root,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(root,"runner.jl"))
write(joinpath(root,"conditions.json"),JSON3.write(Dict("purpose"=>"one-day disposal integration; authored 2 spoiled items per personal store, training off; ordinary candidate selection","days"=>1)))
include(joinpath(source,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String));waste=sum(r.food_resources.waste.counts)
@test waste>=8
@test r.initial_food+r.replenished_food==r.ground+r.consumed+waste+sum(a.inventory+a.personal_stock for a in values(r.final_agents))
println("DISPOSAL_SMOKE ",JSON3.write(Dict("discarded"=>waste,"remaining_spoiled"=>Dict(a=>v[6] for (a,v) in pairs(r.food_resources.personal)),"counts"=>Dict(a=>get(v,:discard_food,0) for (a,v) in pairs(r.counts)))))
