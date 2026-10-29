# Fresh long run of the current source. Keep configured conditions unchanged;
# death, incomplete Sleep and unused social opportunities remain observations.
using JSON3, Test, SHA, Dates
length(ARGS)==3 || error("usage: run_long.jl INPUT.json DAYS NEW_OUTPUT")
const original=abspath(ARGS[1]);const days=parse(Int,ARGS[2]);const out=abspath(ARGS[3])
const repo=normpath(joinpath(@__DIR__,"../.."))
4<=days<=90 || error("long run requires 4..90 days")
ispath(out) && error("fresh output required")
const initial=JSON3.read(read(original,String),Dict{String,Any})
const input=deepcopy(initial);input["config"]["days"]=days
const unchanged=deepcopy(input);unchanged["config"]["days"]=initial["config"]["days"]
@test unchanged==initial
@assert input["scene"]["social_relationships"] && input["scene"]["typed_food"]
mkpath(out);const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
cp(@__FILE__,joinpath(out,"runner.jl"))
write(joinpath(out,"input.json"),JSON3.write(input))
write(joinpath(out,"origin.json"),JSON3.write((mode="fresh-current-source",days=days,
    previous_input=original,previous_input_sha256=bytes2hex(sha256(read(original))),
    input_sha256=bytes2hex(sha256(read(joinpath(out,"input.json")))),
    revision=readchomp(`git -C $repo rev-parse HEAD`),started_utc=string(now(UTC)))))
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
try
    native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
    r=JSON3.read(read(joinpath(out,"run/result.json"),String))
    summary=JSON3.read(read(joinpath(out,"run/summary.json"),String))
    @testset "long social world and bounded learning integrity" begin
        @test length(r.daily)==days && r.ended_us==days*input["clock"]["day_us"]
        @test r.food_resources.consumed[3]==0
        @test sum(r.food_resources.consumed)==r.consumed
        for (i,d) in enumerate(r.daily)
            @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
            @test d.replenished_food==0 && d.food_resources.consumed[3]==0
            @test all(a->isfinite(a.body.reserve) && 0<=a.body.reserve<=100,values(d.physical))
            i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
        end
        for (a,s) in pairs(r.social_relationships)
            old=r.final_agents[a].social;aid=s.aid;m=s.mb
            @test aid.forecasts==aid.resolved+Int(aid.pending!==nothing)
            @test aid.resolved==sum(sum(values(v)) for v in values(aid.outcome_counts);init=0)
            @test length(old.records)+old.records_pruned==aid.resolved && length(old.records)<=128
            @test length(aid.records)<=32 && isempty(old.model)
            @test isfinite(aid.parent.H) && 0<=aid.parent.H<=32
            @test length(m.nodes)<=96 && length(m.pending)<=128
            @test m.frozen===nothing || length(m.frozen.candidates)<=128
            for (other,p) in pairs(s.peers), outcome in keys(p.aid_received)
                @test p.aid_received[outcome]==get(get(aid.outcome_counts,other,Dict()),outcome,0)
            end
        end
    end
    evidence=(days=days,measurement=summary.measurement,food=summary.food,
        food_resources=r.food_resources,wildlife=(alive=r.wildlife.alive,starvation=r.wildlife.starvation_deaths),
        exchange=r.food_exchange.world.counts,
        daily=[(day=i,ground=d.ground,consumed=d.consumed,wildlife_alive=d.wildlife.alive,
            trade=d.food_exchange.world.counts,
            humans=Dict(a=>(reserve=p.body.reserve,position=p.position,inventory=p.inventory,personal_stock=p.personal_stock,
                aid=d.social_relationships[a].aid.outcome_counts,aid_H=d.social_relationships[a].aid.parent.H,
                approach=d.social_relationships[a].approach,
                mb_nodes=length(d.social_relationships[a].mb.nodes),mb_pending=length(d.social_relationships[a].mb.pending),
                mb_merged=d.social_relationships[a].mb.merged,mb_evicted=d.social_relationships[a].mb.evicted,
                mb_admission_blocked=d.social_relationships[a].mb.admission_blocked,
                mb_provisional_evicted=d.social_relationships[a].mb.provisional_evicted,
                sleep_reviews=length(d.social_relationships[a].mb.reviews)) for (a,p) in pairs(d.physical))) for (i,d) in enumerate(r.daily)])
    write(joinpath(out,"evidence.json"),JSON3.write(evidence))
    write(joinpath(out,"completed.json"),JSON3.write((days=days,completed_utc=string(now(UTC)),integrity_passed=true)))
    println("COMPLETED $days days; inspect evidence.json for behavior rather than treating survival as a required outcome")
catch err
    write(joinpath(out,"failed.json"),JSON3.write((failed_utc=string(now(UTC)),error=sprint(showerror,err))))
    rethrow()
end
