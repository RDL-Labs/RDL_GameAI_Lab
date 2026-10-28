using JSON3, Test, SHA
length(ARGS)==2 || error("usage: run.jl INPUT.json NEW_OUTPUT")
const original=abspath(ARGS[1]);const out=abspath(ARGS[2])
const repo=normpath(joinpath(@__DIR__,"../.."))
ispath(out) && error("fresh output required")
mkpath(out);const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
cp(@__FILE__,joinpath(out,"runner.jl"));cp(original,joinpath(out,"input.json"))
write(joinpath(out,"origin.json"),JSON3.write((path=original,sha256=bytes2hex(sha256(read(original))))))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
summary=JSON3.read(read(joinpath(out,"run/summary.json"),String))
f=r.food_resources
@testset "acorn resources and life" begin
    @test length(r.daily)==3
    @test f.consumed[3]==0
    @test f.processed_inputs[3]>=3
    @test f.consumed[4]>=3
    @test sum(f.consumed)==r.consumed
    @test sum(values(f.work_ticks))>=120*f.processed_inputs[3]
    @test all(m->m.kind in (1,2,4),f.meals)
    @test all(m->m.kind!=4 || m.us>=119_000_000,f.meals)
    for (i,d) in enumerate(r.daily)
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
        @test d.replenished_food==0
        @test d.food_resources.consumed[3]==0
        @test sum(d.food_resources.consumed)==d.consumed
        i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
        @test all(a->a.body.reserve>0,values(d.physical))
    end
end
# Same source/input, uninterrupted whole run versus continuing from day 2.
native_main([joinpath(out,"resumed"),"--spec",joinpath(out,"input.json"),
    "--resume-from",joinpath(out,"checkpoints/day-002.jls")])
resumed=JSON3.read(read(joinpath(out,"resumed/result.json"),String))
@testset "acorn and rabbit daily continuation" begin
    @test r==resumed
end
evidence=(config=summary.config,measurement=summary.measurement,food=summary.food,food_resources=f,
    humans=summary.agents,digestion=r.digestion,wildlife=(alive=r.wildlife.alive,starvation=r.wildlife.starvation_deaths),
    daily=[(day=i,food=d.food_resources,humans=Dict(a=>(reserve=v.body.reserve,position=v.position,inventory=v.inventory) for (a,v) in pairs(d.physical))) for (i,d) in enumerate(r.daily)],
    continuation_identical=true)
write(joinpath(out,"evidence.json"),JSON3.write(evidence))
write(joinpath(out,"completed.json"),JSON3.write((days=3,processed=f.processed_inputs[3],eaten=f.consumed[4])))
println("COMPLETED acorns=$(f.processed_inputs[3]) processed, $(f.consumed[4]) eaten")
