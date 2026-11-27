using Test,JSON3
include("../../src/lw/LW.jl")
for file in ("src/body/activity_wear.jl","src/body/activity_capacity.jl","src/lw/configured_paths/return_rest_local.jl")
    endswith(file,"activity_wear.jl") && isdefined(LW,:ActivityWear) && continue
    endswith(file,"activity_capacity.jl") && isdefined(LW,:ActivityCapacity) && continue
    endswith(file,"return_rest_local.jl") && isdefined(LW,:configured_return_rest_candidates) && continue
    Base.include(LW,joinpath(@__DIR__,"../..",file))
end
const Capacity=LW.ActivityCapacity
rows=Any[]
@testset "near home versus rest before a long return" begin
    body=Capacity.State(wear=.35,fatigue=.69)
    @test Capacity.ratio(body)>1
    for hours in (.05,.25,.5,1.,2.)
        choices=LW.configured_return_rest_candidates(body,hours)
        @test length(choices)==2
        @test all(isfinite(c["priority"]) for c in choices)
        loop=LW.BasicLoop("return-profile";probabilistic=true,seed=1)
        probabilities=LW.method_distribution(loop,choices)
        counts=Dict("home"=>0,"rest_then_home"=>0)
        for seed in 1:128
            agent=LW.BasicLoop("return-agent";probabilistic=true,seed=seed)
            chosen=LW.choose_method!(agent,choices,"return")
            LW.resolve_method!(agent,"return",nothing,nothing;creditable=false,goal_H_increment=0.)
            counts[chosen["method"]]+=1
        end
        push!(rows,(return_hours=hours,home_probability=probabilities[1],choices=choices,counts=counts))
    end
    @test first(rows).home_probability>.5
    @test last(rows).home_probability<.5
    @test first(rows).counts["home"]>last(rows).counts["home"]
    @test issorted([r.home_probability for r in rows];rev=true)
    @test body.fatigue==.69 && body.physical.wear==.35 # Forecast never changes live body.
    near=LW.configured_return_rest_forecast(body,.05,0.)
    @test near.feasible && near.max_ratio>1
    @test near.body.fatigue<body.fatigue
    # Safety value is an input, not unconditional preference for the home ID.
    neutral=LW.configured_return_rest_forecast(body,.05,0.;home_value=0.)
    @test neutral.priority<near.priority
    broken=Capacity.State(damage=1.,fatigue=.69)
    @test only(LW.configured_return_rest_candidates(broken,.05))["method"]=="rest_here"
    @test_throws ArgumentError LW.configured_return_rest_candidates(body,4.)
end
out=isempty(ARGS) ? joinpath(@__DIR__,"return_rest_result.json") : ARGS[1]
write(out,JSON3.write((conditions=(wear=.35,fatigue=.69,capacity=.65,seeds=128,horizon_hours=4.,pause_hours=.5),rows=rows)))
println(JSON3.write([(return_hours=r.return_hours,home_probability=r.home_probability,counts=r.counts) for r in rows]))
