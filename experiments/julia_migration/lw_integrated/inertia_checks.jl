include(joinpath(@__DIR__,"probabilistic_checks.jl"))
include(joinpath(@__DIR__,"checks.jl"))
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--orientation","on",
    "--relation-field","on","--hazards","mixed","--safety-methods","continuous","--food-body","on","--body-field","on",
    "--movement-inertia",mode,"--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
    @testset "living continuation" begin
        @test sum(s.continued for s in values(r.movement_inertia))==0
        @test all(length(s.records)<=32 for s in values(r.movement_inertia))
        @test all(s.H<=32 for s in values(r.movement_inertia))
    end
 end
end
