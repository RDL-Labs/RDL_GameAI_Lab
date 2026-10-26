include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "night fear is forecast residual, not tick failure" begin
 day=17280_000_000;night=11520_000_000
 clear=D("coverage"=>"complete","features"=>Any[])
 close=D("seconds"=>20.,"margin"=>864.,"kind"=>"observed_home")
 far=D("seconds"=>4000.,"margin"=>864.,"kind"=>"observed_chain")
 unknown=D("seconds"=>256.,"margin"=>4320.,"kind"=>"unconfirmed")
 early=night_fear_state()
 @test night_fear_update!(early,close,false,clear,0,day,night)==0
 nearstate=night_fear_state();farstate=night_fear_state();unseen=night_fear_state()
 now=8000_000_000
 @test night_fear_update!(nearstate,close,false,clear,now,day,night)==0
 @test night_fear_update!(farstate,far,false,clear,now,day,night)>0
 @test night_fear_update!(unseen,unknown,false,clear,now,day,night)>0
 @test unseen["anticipatory_evaluations"]==1
 h=unseen["H"];n=unseen["evaluations"]
 @test night_fear_update!(unseen,unknown,false,clear,now,day,night)==h
 @test unseen["evaluations"]==n
 # Keep the predicted residual constant while the clock advances.
 fixed=night_fear_state()
 for i in 0:1999
  e=D("seconds"=>5000.0-i,"margin"=>0.,"kind"=>"observed_chain")
  night_fear_update!(fixed,e,false,clear,(8000+i)*1_000_000,day,night)
 end
 target=(5000-3520)/2160
 @test 0<fixed["H"]<=target+1e-12
 before=fixed["H"]
 @test 0<night_fear_update!(fixed,close,true,clear,10000_000_000,day,night)<before
 # Unknown safety evidence cannot erase fear just because home is nearby.
 before=fixed["H"]
 @test night_fear_update!(fixed,close,true,nothing,10001_000_000,day,night)≈before
 danger=D("coverage"=>"complete","features"=>[D("distance"=>1.)])
 @test night_fear_update!(fixed,close,true,danger,10002_000_000,day,night)>before
 before=fixed["H"]
 @test 0<night_fear_update!(fixed,close,false,clear,day,day,night)<before
 rng=Xoshiro(8);fixed["H"]=8.
 @test !night_fear_request!(fixed,false,true,day,rng)
 @test fixed["food_blocks"]==1
 @test night_fear_request!(fixed,true,true,day+1,rng)
 x=night_fear_request!(fixed,false,false,day+2,rng);n=fixed["requests"]
 @test night_fear_request!(fixed,false,false,day+2,rng)==x && fixed["requests"]==n
 @test length(fixed["records"])<=64
 # Unknown route receives a positive estimate and uncertainty, never a fabricated edge.
 s=mb_map_state("a");f=night_fear_state()
 e=night_return_estimate!(s,f,nothing,false,0,day)
 @test e["kind"]=="unconfirmed" && e["seconds"]>0 && e["margin"]>0
 @test isempty(s["edges"])
 @test night_return_estimate!(s,f,nothing,true,1,day)["seconds"]==0
 @test f["estimate"]===nothing
end
