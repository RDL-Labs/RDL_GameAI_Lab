using JSON3
include("../../src/lw/LW.jl")
x=JSON3.read(read(joinpath(@__DIR__,"predator_3d_spec.json"),String),Dict{String,Any})
x["config"]["days"]=1
x["scene"]["positions"]=x["scene"]["positions"][1:3]
x["scene"]["reserve"]=x["scene"]["reserve"][1:3]
for key in ("initial_inventory","initial_inventory_kinds","initial_personal_stock","experimental_actor_ids"); x["scene"][key]=x["scene"][key][1:3]; end
input=JSON3.read(JSON3.write(x))
println("Ambient vision human + predator + rabbit full day smoke")
result=LW.run_integrated(input)
println("FULL_DAY_PASS")
