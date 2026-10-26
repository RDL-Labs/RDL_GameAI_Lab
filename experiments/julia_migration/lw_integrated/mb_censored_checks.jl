include(joinpath(@__DIR__,"mb_parent_checks.jl"))
@testset "censored evidence is a lower bound and one sample per attempt" begin
 s=mb_map_state("a");p=D("action"=>"scan")
 mb_parent_begin!(s,p,"food",nothing,0);a=s["parent_mb"]["active"]["food"]
 original=deepcopy(a["estimate"]);a["actions"]=5000;a["energy"]=100.
 mb_parent_learn!(s,"food",a,false,"unfinished")
 model=s["parent_mb"]["models"]["food:search"]
 next=mb_parent_estimate!(s,D(),"food",nothing)
 @test next["upper_actions"]>5000
 @test next["mean_is_lower_bound"] && next["tail_mass"]>0
 @test model["samples"]==0 && model["completed"]==0
 @test next["expected_actions"]!=5000 && next["prior_weight"]==.5
 @test model["energy_rate"]>.01
 @test a["estimate"]==original
 updates=model["censored_updates"]
 mb_parent_learn!(s,"food",a,false,"unfinished")
 @test model["censored_updates"]==updates && length(model["observations"])==1
 a["actions"]=6000;a["energy"]=120.
 mb_parent_learn!(s,"food",a,false,"pause")
 @test length(model["observations"])==1 && only(model["observations"])["actions"]==6000
 @test mb_parent_estimate!(s,D(),"food",nothing)["prior_weight"]==.5
 a["last_us"]=0
 mb_parent_H_increment!(s,"food","op:0:a",true,1_000_000)
 @test length(model["observations"])==1 && only(model["observations"])["completed"]
 @test model["samples"]==1
 @test !mb_parent_estimate!(s,D(),"food",nothing)["mean_is_lower_bound"]
end
@testset "experience replaces prior influence and adapts in both directions" begin
 s=mb_map_state("a")
 function completed!(s,t,actions)
  p=D("action"=>"scan");mb_parent_begin!(s,p,"food",nothing,t)
  a=s["parent_mb"]["active"]["food"];a["actions"]=actions;a["energy"]=actions*.002;a["last_us"]=t
  mb_parent_H_increment!(s,"food","op:$t:a",true,t+1_000_000)
 end
 for i in 1:20;completed!(s,i*1_000_000,64);end
 learned=mb_parent_estimate!(s,D(),"food",nothing)
 @test learned["prior_weight"]≈1/21
 @test abs(learned["expected_actions"]-64)<4
 for i in 21:160;completed!(s,i*1_000_000,16);end
 latest=mb_parent_estimate!(s,D(),"food",nothing)
 @test latest["expected_actions"]<learned["expected_actions"]
 @test length(s["parent_mb"]["models"]["food:search"]["observations"])==128
 @test latest["prior_weight"]≈1/129
 @test s["parent_mb"]["models"]["food:search"]["energy_rate"]<.003
end
@testset "pause and purpose switch retain frozen parent and censored evidence" begin
 s=mb_map_state("a");p=D("action"=>"scan")
 mb_parent_begin!(s,p,"home",nothing,0)
 for i in 0:9;mb_parent_record!(s,p,.001,i*1_000_000);end
 a=s["parent_mb"]["active"]["home"];frozen=deepcopy(a["estimate"])
 mb_parent_record!(s,D("action"=>"rest"),0.,10_000_000)
 model=s["parent_mb"]["models"]["home:search"]
 @test only(model["observations"])["reason"]=="pause"
 @test !only(model["observations"])["completed"] && model["samples"]==0
 q=D("action"=>"pickup");mb_parent_begin!(s,q,"food",D("distance"=>1.),11_000_000)
 @test length(model["observations"])==1
 @test a["estimate"]==frozen && a["actions"]==10
end
