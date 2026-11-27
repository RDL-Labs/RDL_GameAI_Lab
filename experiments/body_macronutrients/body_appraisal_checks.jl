using Test,JSON3
include("../../src/lw/LW.jl")
isdefined(LW,:configured_body_appraisal) || Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/body_appraisal_local.jl"))
const C=LW.ActivityCapacity
distribution(choices)=Dict(c["method"]=>p for (c,p) in zip(choices,LW.method_distribution(LW.BasicLoop("appraisal";probabilistic=true,seed=1),choices)))
rows=Any[]
@testset "early body appraisal, unchanged physical limit" begin
    for wear in (.1,.35,.5,.7,.9),hours in (.1,.5,1.,2.)
        b=C.State(wear=wear,fatigue=0.)
        early=LW.configured_body_appraisal_candidates(b,hours)
        late=LW.configured_body_appraisal_candidates(b,hours;reference=1.)
        @test [c["method"] for c in early]==[c["method"] for c in late]
        @test b.physical.wear==wear && b.fatigue==0
        p=distribution(early);q=distribution(late)
        @test sum(values(p))≈1.
        @test get(p,"continue",0.)<=get(q,"continue",0.)+1e-12
        push!(rows,(wear=wear,return_hours=hours,early=p,late=q))
    end
    b=C.State(wear=.5,fatigue=0.)
    x=LW.configured_body_appraisal_candidates(b,.5)
    b.fatigue=99.
    @test x==LW.configured_body_appraisal_candidates(b,.5) # No hidden independent fatigue in scoring.
    @test C.capacity(b)==.5
    @test LW.configured_body_appraisal(b)>1
    rich=LW.configured_body_appraisal_candidates(b,.5;rules=merge(LW.SLEEP_REPAIR_LOCAL,(work_value=8.,)))
    @test distribution(rich)["continue"]>distribution(x)["continue"]
    broken=C.State(wear=1.)
    @test !("home" in [c["method"] for c in LW.configured_body_appraisal_candidates(broken,.5)])
end
write(ARGS[1],JSON3.write((settings=LW.BODY_APPRAISAL_LOCAL,rows=rows)))
println(JSON3.write(rows))
