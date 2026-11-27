using Test,JSON3,Statistics,Serialization
include("../../src/lw/LW.jl")
isdefined(LW,:ActivityWear) || Base.include(LW,joinpath(@__DIR__,"../../src/body/activity_wear.jl"))
Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/activity_wear_local.jl"))
const Wear=LW.ActivityWear
function home_probability(s,effort;return_hours=.5)
    choices=LW.configured_activity_wear_candidates(s.wear,1.,return_hours;effort)
    loop=LW.BasicLoop("wear-profile";probabilistic=true,seed=1)
    p=LW.method_distribution(loop,choices)
    p[findfirst(c->c["method"]=="home",choices)]
end
profiles=Any[];trials=Any[]
@testset "activity wear with ample repair nutrition" begin
    s=Wear.State();Wear.step!(s,:walk,4.)
    @test s.wear≈.24
    before=s.wear;Wear.step!(s,:eat,1.;repair_supply=1.)
    @test s.wear==before # Eating alone cannot erase accumulated wear.
    rested=deepcopy(s);slept=deepcopy(s);starved=deepcopy(s)
    Wear.step!(rested,:rest,1.);Wear.step!(slept,:sleep,1.)
    Wear.step!(starved,:sleep,1.;repair_supply=0.)
    @test slept.wear<rested.wear<s.wear
    @test starved.wear==s.wear
    Wear.step!(s,:sleep,8.)
    @test s.wear==0 && s.accumulated≈s.repaired
    exhausted=Wear.State();Wear.step!(exhausted,:walk,100.)
    @test Wear.ability(exhausted)==0
    @test length(LW.configured_activity_wear_candidates(.95,1.,.5))==1
    @test_throws ArgumentError Wear.step!(s,:walk,-1.)
    io=IOBuffer();serialize(io,exhausted);seekstart(io)
    @test deserialize(io).wear==exhausted.wear
    for effort in (1.,2.)
        s=Wear.State()
        for hour in 0:12
            push!(profiles,(effort=effort,hour=hour,wear=s.wear,ability=Wear.ability(s),home_probability=home_probability(s,effort)))
            Wear.step!(s,:walk,1.;effort)
        end
        for seed in 1:128
            s=Wear.State();loop=LW.BasicLoop("wear-agent";probabilistic=true,seed=seed)
            # Fixed test task: one hour of walking before each deliberation.
            for hour in 1:24
                Wear.step!(s,:walk,1.;effort)
                source="wear:$hour"
                chosen=LW.choose_method!(loop,LW.configured_activity_wear_candidates(s.wear,1.,.5;effort),source)
                LW.resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
                if chosen["method"]=="home"
                    departure_wear=s.wear
                    Wear.step!(s,:walk,.5;effort)
                    arrived_wear=s.wear
                    Wear.step!(s,:sleep,8.)
                    push!(trials,(effort=effort,seed=seed,return_hour=hour,departure_wear=departure_wear,arrived_wear=arrived_wear,morning_wear=s.wear))
                    @test s.wear≈s.accumulated-s.repaired atol=1e-12
                    break
                end
            end
        end
    end
    for effort in (1.,2.)
        rows=filter(r->r.effort==effort,profiles)
        @test issorted([r.home_probability for r in rows])
    end
    normal=filter(r->r.effort==1.,trials);heavy=filter(r->r.effort==2.,trials)
    @test length(normal)==length(heavy)==128
    @test mean(r.return_hour for r in heavy)<mean(r.return_hour for r in normal)
end
summary=[(effort=e,mean_return_hour=mean(r.return_hour for r in trials if r.effort==e),
    median_return_hour=median([r.return_hour for r in trials if r.effort==e]),
    majority_home_hour=first(r.hour for r in profiles if r.effort==e && r.home_probability>=.5),
    max_morning_wear=maximum(r.morning_wear for r in trials if r.effort==e)) for e in (1.,2.)]
out=length(ARGS)>0 ? ARGS[1] : joinpath(@__DIR__,"activity_wear_result.json")
write(out,JSON3.write((conditions=(food="ample constant repair supply; nutrient debiting not connected",seeds=128,work_hours=1.,return_hours=.5,sleep_hours=8.),summary=summary,profiles=profiles,trials=trials)))
println(JSON3.write(summary))
