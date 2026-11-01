using JSON3, Test
length(ARGS)==2 || error("usage: population_input.jl BASE_INPUT NEW_INPUT")
input=JSON3.read(read(ARGS[1],String),Dict{String,Any})
s=input["scene"];c=input["config"];n=10
ids=vcat(["npc_a","npc_b","npc_c"],["npc_"*lpad(i,3,'0') for i in 4:n])
s["experimental_actor_ids"]=ids;c["days"]=10
home=s["home"]
s["positions"]=[[home[1]+.8cos(2pi*i/n),home[2]+.8sin(2pi*i/n)] for i in 0:n-1]
s["reserve"]=fill(70,n);s["initial_inventory"]=fill(1,n)
s["initial_inventory_kinds"]=[[3] for _ in ids]
s["initial_personal_stock"]=fill(60,n)
s["initial_personal_food_counts"]=Dict(a=>[60,0,0,0] for a in ids)
c["mb_sensitivities"]=Dict(a=>Dict(k=>(mod1(i,3)==1 ? .5 : 1.) for k in ("delay","stagnation","energy","contradiction")) for (i,a) in enumerate(ids))
for site in s["food"];site["stock"]=round(Int,site["stock"]*n/3);end
s["finite_food_layout"]=Dict("version"=>"ten-actor-scaled-stock-v1","ground_total"=>sum(f["stock"] for f in s["food"]),"initial_private_each"=>60)
# Seasonal rates stay fixed; they apply to the scaled per-site stock.
@test s["item_attention"]===true
@test length(ids)==length(s["positions"])==10
@test sum(s["initial_personal_stock"])==600
@test all(hypot(p[1]-o["x"],p[2]-o["z"])>o["radius"] for p in s["positions"] for o in s["obstacles"] if get(o,"solid",true))
ispath(ARGS[2]) && error("fresh input required")
write(ARGS[2],JSON3.write(input))
println("actors=10 days=10 ground=",sum(f["stock"] for f in s["food"])," private=600 inventory=10")
