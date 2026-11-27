using Test,JSON3,Statistics,Serialization
include("../../src/lw/LW.jl")
for file in ("src/body/activity_wear.jl","src/body/activity_capacity.jl","src/lw/configured_paths/activity_wear_local.jl")
    Base.include(LW,joinpath(@__DIR__,"../..",file))
end
const Capacity=LW.ActivityCapacity
function rest_probability(body;effort=1.,return_hours=.5)
    choices=LW.configured_activity_capacity_candidates(body,1.,return_hours;effort)
    probabilities=LW.method_distribution(LW.BasicLoop("profile";probabilistic=true,seed=1),choices)
    sum(probabilities[i] for i in eachindex(choices) if choices[i]["method"]!="continue")
end
profiles=Any[];trials=Any[]
@testset "fatigue constrained by changing body capacity" begin
    healthy=Capacity.State(fatigue=.3);worn=Capacity.State(wear=.35,fatigue=.3)
    @test Capacity.capacity(worn)<Capacity.capacity(healthy)
    @test rest_probability(worn)>rest_probability(healthy)
    # Same slow-wear cost and same fatigue: capacity reduction alone must matter.
    @test rest_probability(Capacity.State(fatigue=.3,damage=.35))>rest_probability(healthy)
    @test rest_probability(healthy;return_hours=1.)>rest_probability(healthy;return_hours=.1)
    hurt=Capacity.State(fatigue=.5);hurt.damage=.6
    @test hurt.fatigue==.5 && Capacity.ratio(hurt)>1
    @test only(LW.configured_activity_capacity_candidates(hurt,1.,.5))["method"]=="rest_here"
    Capacity.step!(hurt,:rest,1.)
    @test Capacity.ratio(hurt)<1
    fed=deepcopy(worn);Capacity.step!(fed,:eat,1.)
    @test fed.fatigue==worn.fatigue && Capacity.capacity(fed)==Capacity.capacity(worn)
    predicted=Capacity.forecast(worn,1.,.5)
    actual=deepcopy(worn);Capacity.step!(actual,:walk,1.5)
    @test predicted.work_home.fatigue≈actual.fatigue
    @test Capacity.capacity(predicted.work_home)≈Capacity.capacity(actual)
    @test worn.fatigue==.3 && worn.physical.wear==.35
    @test isinf(Capacity.ratio(Capacity.State(damage=1.)))
    @test_throws ArgumentError Capacity.forecast(healthy,-1.,.5)
    io=IOBuffer();serialize(io,worn);seekstart(io)
    @test Capacity.ratio(deserialize(io))==Capacity.ratio(worn)
    for (label,initial_wear,effort) in (("healthy",0.,1.),("worn",.35,1.),("heavy",0.,2.))
        for hour in (0.,1.,2.,3.,4.)
            body=Capacity.State(wear=initial_wear,fatigue=.15)
            Capacity.step!(body,:walk,hour;effort)
            push!(profiles,(condition=label,hour=hour,wear=body.physical.wear,fatigue=body.fatigue,
                capacity=Capacity.capacity(body),rest_probability=rest_probability(body;effort)))
        end
        for seed in 1:128
            body=Capacity.State(wear=initial_wear,fatigue=.15)
            loop=LW.BasicLoop("capacity-agent";probabilistic=true,seed=seed)
            for hour in 0:24
                source="capacity:$hour"
                chosen=LW.choose_method!(loop,LW.configured_activity_capacity_candidates(body,1.,.5;effort),source)
                LW.resolve_method!(loop,source,nothing,nothing;creditable=false,goal_H_increment=0.)
                if chosen["method"]!="continue"
                    capacity_at_choice=Capacity.capacity(body);fatigue_at_choice=body.fatigue
                    if chosen["method"]=="home"
                        Capacity.step!(body,:walk,.5;effort)
                        @test Capacity.ratio(body)<1
                    end
                    Capacity.step!(body,:sleep,8.)
                    push!(trials,(condition=label,seed=seed,hour=hour,choice=chosen["method"],fatigue=fatigue_at_choice,
                        capacity=capacity_at_choice,morning_capacity=Capacity.capacity(body),morning_fatigue=body.fatigue))
                    break
                end
                Capacity.step!(body,:walk,1.;effort)
            end
        end
    end
    @test length(trials)==384
    healthy_mean=mean(r.hour for r in trials if r.condition=="healthy")
    @test mean(r.hour for r in trials if r.condition=="worn")<healthy_mean
    @test mean(r.hour for r in trials if r.condition=="heavy")<healthy_mean
end
summary=[(condition=label,mean_return_hour=mean(r.hour for r in trials if r.condition==label),
    median_return_hour=median([r.hour for r in trials if r.condition==label]),
    immediate_returns=count(r->r.condition==label && r.hour==0,trials)) for label in ("healthy","worn","heavy")]
out=isempty(ARGS) ? joinpath(@__DIR__,"activity_capacity_result.json") : ARGS[1]
write(out,JSON3.write((summary=summary,profiles=profiles,trials=trials)))
println(JSON3.write(summary))
