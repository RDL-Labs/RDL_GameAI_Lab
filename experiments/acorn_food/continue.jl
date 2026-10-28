using JSON3, Test, SHA
length(ARGS)==3 || error("usage: continue.jl PREVIOUS_OUTPUT FINAL_DAY NEW_OUTPUT")
const previous=abspath(ARGS[1]);const final_day=parse(Int,ARGS[2]);const out=abspath(ARGS[3])
const original=JSON3.read(read(joinpath(previous,"input.json"),String),Dict{String,Any})
const start_day=Int(original["config"]["days"])
start_day<final_day<=90 || error("final day must extend the previous run, up to 90")
ispath(out) && error("fresh output required")
const saved=joinpath(previous,"checkpoints","day-"*lpad(start_day,3,'0')*".jls")
isfile(saved) || error("missing final daily checkpoint")
mkpath(out)
cp(joinpath(previous,"source"),joinpath(out,"source"))
cp(@__FILE__,joinpath(out,"runner.jl"))
const input=deepcopy(original);input["config"]["days"]=final_day
const unchanged=deepcopy(input);unchanged["config"]["days"]=start_day
@test original==unchanged
write(joinpath(out,"input.json"),JSON3.write(input))
write(joinpath(out,"origin.json"),JSON3.write((previous=previous,checkpoint=saved,
    checkpoint_sha256=bytes2hex(sha256(read(saved))),start_after_day=start_day,final_day=final_day)))
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),
    "--resume-from",saved,"--checkpoint-dir",joinpath(out,"checkpoints")])
const r=JSON3.read(read(joinpath(out,"run/result.json"),String))
const summary=JSON3.read(read(joinpath(out,"run/summary.json"),String))
const before=JSON3.read(read(joinpath(previous,"run/result.json"),String))
const f=r.food_resources
@testset "continued acorn world integrity" begin
    @test length(r.daily)==final_day
    @test r.daily[1:start_day]==before.daily
    @test r.day_starts[1:start_day]==before.day_starts
    @test f.consumed[3]==0
    @test f.processed_inputs[3]>=before.food_resources.processed_inputs[3]
    @test sum(f.consumed)==r.consumed
    @test sum(values(f.work_ticks))>=120*f.processed_inputs[3]
    for (i,d) in enumerate(r.daily)
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
        @test d.replenished_food==0
        @test d.food_resources.consumed[3]==0
        @test sum(d.food_resources.consumed)==d.consumed
        i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
        @test all(a->isfinite(a.body.reserve) && 0<=a.body.reserve<=100,values(d.physical))
    end
end
# Measurement covers the continued interval; cumulative results include earlier days.
const evidence=(config=summary.config,measurement=summary.measurement,
    measured_days=(from=start_day+1,to=final_day),food=summary.food,food_resources=f,
    humans=summary.agents,digestion=r.digestion,
    ground_by_kind=[sum(r.world_checkpoint.stock[i] for i in eachindex(r.world_checkpoint.stock)
        if f.site_kinds[i]==k;init=0) for k in 1:4],
    wildlife=(alive=r.wildlife.alive,starvation=r.wildlife.starvation_deaths),
    daily=[(day=i,food=d.food_resources,ground=d.ground,counts=d.counts,
        wildlife=(alive=d.wildlife.alive,starvation=d.wildlife.starvation_deaths),
        humans=Dict(a=>(reserve=v.body.reserve,position=v.position,inventory=v.inventory) for (a,v) in pairs(d.physical)))
        for (i,d) in enumerate(r.daily)],previous_days_identical=true)
write(joinpath(out,"evidence.json"),JSON3.write(evidence))
write(joinpath(out,"completed.json"),JSON3.write((days=final_day,continued_from=start_day,
    processed=f.processed_inputs[3],eaten=f.consumed[4])))
println("COMPLETED through day $final_day: acorns=$(f.processed_inputs[3]) processed, $(f.consumed[4]) eaten")
