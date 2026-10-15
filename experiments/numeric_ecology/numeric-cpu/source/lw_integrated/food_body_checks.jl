include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "metabolism hunger and retention" begin
 b=Body(10.,0.,100.,0.);after=metabolize(b,17280.)
 @test after.reserve≈84.
 @test after.burst==b.burst && after.strain==b.strain
 @test metabolize(Body(0.,1.,.1,0.),17280.).reserve==0
 @test_throws ErrorException metabolize(b,-1.)
 h=hunger_state("a");hunger_update!(h,"a",0,80.)
 @test !hunger_select(h)
 hunger_update!(h,"a",5_000_000,80.)
 @test h["H"]==1 && hunger_select(h)
 hunger_update!(h,"a",5_000_000,80.)
 @test h["comparisons"]==1
 hunger_update!(h,"a",10_000_000,90.)
 @test h["H"]==0 && !hunger_select(h)
 @test food_band(2)=="low" && food_band(3)=="some" && food_band(6)=="many"
 obs=D("self_id"=>"a","inventory"=>2,"body"=>D("reserve"=>40.))
 @test retention_cost(obs,h)==2.
 h["H"]=2
 @test retention_cost(obs,h)==3.
 obs["inventory"]=6
 @test retention_cost(obs,h)==0.
 @test_throws ErrorException hunger_update!(h,"b",11_000_000,80.)
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--food-body",mode,"--social-response","experience","--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "living food body" begin
   @test all(v>0 && v<=48.000001 for v in values(r.food_body.metabolic_loss))
   @test all(h.comparisons>0 && length(h.records)<=32 for h in values(r.food_body.hunger))
   @test sum(get(c,:eat,0) for c in values(r.counts))>6
  end
 end
end
