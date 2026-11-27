using Test,JSON3
include("../../src/lw/LW.jl")
Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/sleep_repair_local.jl"))
const C=LW.ActivityCapacity
rows=Any[]
@testset "sleep-only physical repair" begin
    body=C.State(wear=1.,fatigue=1.)
    C.step!(body,:rest,1.;wear_rules=LW.SLEEP_REPAIR_WEAR)
    @test body.physical.wear==1.
    @test C.capacity(body)==0.
    C.step!(body,:sleep,1.;wear_rules=LW.SLEEP_REPAIR_WEAR)
    @test body.physical.wear≈.9
    for wear in (.1,.4,.7,.9),hours in (.1,.5,1.,2.)
        initial=C.State(wear=wear,fatigue=.2)
        choices=Any[]
        for method in ("continue","home","sleep_then_home","sleep_here")
            f=LW.configured_sleep_repair_forecast(initial,hours,method)
            f.feasible && push!(choices,LW.D("method"=>method,"priority"=>f.priority,"question"=>"activity_recovery"))
        end
        p=LW.method_distribution(LW.BasicLoop("sleep-repair";probabilistic=true,seed=1),choices)
        @test all(isfinite,p) && sum(p)≈1.
        @test initial.physical.wear==wear && initial.fatigue==.2
        push!(rows,(wear=wear,return_hours=hours,probabilities=Dict(c["method"]=>v for (c,v) in zip(choices,p))))
    end
    for wear in (.1,.4,.7,.9)
        @test issorted([get(r.probabilities,"continue",0.) for r in rows if r.wear==wear];rev=true)
    end
    @test last(rows).probabilities["sleep_here"]>.99
end
write(ARGS[1],JSON3.write((rules=LW.SLEEP_REPAIR_LOCAL,rows=rows)))
println(JSON3.write(rows))
