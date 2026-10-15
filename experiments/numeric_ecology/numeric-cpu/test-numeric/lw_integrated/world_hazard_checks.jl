include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "Python fixed territorial and patrol trajectory" begin
 s=dynamic_hazards()
 rows=JSON3.read(read(joinpath(@__DIR__,"world_hazard_reference.json"),String))
 for r in rows
  positions=Dict("a"=>(Float64(r.agent.x),Float64(r.agent.z)))
  advance_hazards!(s,Int(r.now),positions,Any[])
  @test s["territory"]["mode"]==r.territory.mode
  @test collect(s["territory"]["position"])≈[r.territory.position.x,r.territory.position.z]
  @test collect(s["patrol"]["position"])≈[r.patrol.position.x,r.patrol.position.z]
 end
 old=deepcopy(s);advance_hazards!(s,60_000_000,Dict("a"=>(0.,0.)),Any[])
 @test old==s
 @test_throws ErrorException advance_hazards!(s,0,Dict(),Any[])
 @test length(s["records"])==32
end
out=ARGS[1]
for mode in ("off","mixed")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--hazards",mode,"--running","on","--food-body","on","--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="mixed"
  @testset "living World hazard" begin
   @test r.world_hazards.last_us==51_839_000_000
   @test sum(values(r.world_hazards.counts))==207357
   @test sum(s.overrides for s in values(r.safety))>0
  end
 end
end
