include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "Python initial orientation correspondence" begin
 s=orientation_state("npc_a");clock=native_clock()
 rows=JSON3.read(read(joinpath(@__DIR__,"orientation_reference.json"),String))
 for (i,r) in enumerate(rows)
    cue=sky_sample("npc_a","ob:$i",Int(r.now),Float64(r.yaw),clock;available=r.available)
    @test cue["relative_center"]==r.center && cue["cue"]==r.cue
    observe_sky!(s,cue)
    @test orientation_scan!(s,clock)==r.angle
    r.counts!==nothing && @test s["last"]["counts"]==collect(r.counts)
 end
 @test length(s["history"])==257
 cue=last(s["history"]);n=s["samples"];observe_sky!(s,cue)
 @test s["samples"]==n
 @test_throws Exception observe_sky!(s,merge(cue,D("actor"=>"npc_b")))
 @test_throws Exception observe_sky!(s,merge(cue,D("relative_center"=>123)))
 @test_throws Exception observe_sky!(s,merge(cue,D("capture_us"=>0)))
 @test !any(haskey(cue,k) for k in ("position","home","destination"))
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--orientation",mode,
    "--hazards","mixed","--safety-methods","continuous","--food-body","on","--general-sleep","apply",
    "--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
    @testset "orientation in continuous life" begin
        @test all(s.samples==51840 for s in values(r.orientation))
        @test all(length(s.history)==257 for s in values(r.orientation))
        @test sum(s.selections for s in values(r.orientation))>0
        @test all(s.left+s.right==s.selections for s in values(r.orientation))
    end
 end
end
