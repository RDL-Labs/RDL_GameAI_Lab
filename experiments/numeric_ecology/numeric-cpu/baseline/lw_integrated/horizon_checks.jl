include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "cross-day exploration evidence" begin
 s=horizon_state("a")
 for i in 1:15;horizon_result!(s,"a","op$i","exploration","moved",false);end
 @test s["H"]==1 && s["count"]==7
 prior=deepcopy(s);@test !horizon_result!(s,"a","op15","exploration","moved",false)
 @test s==prior
 horizon_result!(s,"a","night","night","waited",false)
 @test s["H"]==1 && s["count"]==7
 horizon_result!(s,"a","next-day","exploration","turned",false)
 @test s["H"]==2 && s["count"]==0
 @test !horizon_result!(s,"a","unlinked","exploration","moved",false;linked=false)
 @test_throws Exception horizon_result!(s,"b","wrong","exploration","moved",false)
 fan=D("source"=>"current","features"=>[D("range_band"=>"far","azimuth"=>[37.5,52.5])])
 move=D("energy"=>D("rows"=>[D("cost"=>1.) for _ in 1:5]))
 cs=horizon_candidates(s,fan,move)
 @test length(cs)==1 && cs[1]["direction"]==3 && cs[1]["priority"]==3.
 move["energy"]["rows"][4]["cost"]=nothing
 @test isempty(horizon_candidates(s,fan,move))
 horizon_result!(s,"a","food","return","picked_up",true)
 @test s["H"]==0 && s["count"]==0 && isempty(horizon_candidates(s,fan,move))
 for i in 1:400;horizon_result!(s,"a","long$i","exploration","blocked",false);end
 @test s["H"]==32 && length(s["events"])==16
end
for mode in ("off","on")
 dir=joinpath(ARGS[1],mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--orientation","on","--exploration-horizon",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "living cross-day horizon" begin
   @test sum(s.selections for s in values(r.exploration_horizon))>0
   @test all(s.H<=32 && s.count<8 && length(s.events)<=16 for s in values(r.exploration_horizon))
  end
 end
end
