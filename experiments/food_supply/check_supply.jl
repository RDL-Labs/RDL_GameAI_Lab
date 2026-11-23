using JSON3,Test
include("../../src/lw/world/seasonal_food.jl")
input=JSON3.read(read(joinpath(@__DIR__,"input_four_actor.json"),String))
season=seasonal_food_config(input.scene,true,1)
food=input.scene.food;stock=zeros(Int,length(food));rows=Any[]
gather=findall(f->f.food_kind in (1,3),food)
for day in 1:60
 fill!(stock,0) # Available production with headroom; not a simulated harvest.
 total=seasonal_replenish_food!(stock,food,season,day)
 push!(rows,(day,gather=sum(stock[gather]),all_resources=total))
 @test all(stock[i]<=food[i].stock for i in eachindex(stock))
end
expected=sum(food[i].stock for i in gather)*(season.low_rate+season.high_rate)/2*60
@test abs(sum(r.gather for r in rows)-expected)<=length(gather) # per-site integer rounding
stock=Int[f.stock for f in food]
@test seasonal_replenish_food!(stock,food,season,8)==0
report=(scope="world production only; empty sites before each day",period=60,
 gather_min=minimum(r.gather for r in rows),gather_max=maximum(r.gather for r in rows),
 gather_mean=sum(r.gather for r in rows)/60,rows)
write(joinpath(@__DIR__,"supply_check.json"),JSON3.write(report))
println(JSON3.write((minimum=report.gather_min,maximum=report.gather_max,mean=report.gather_mean)))
