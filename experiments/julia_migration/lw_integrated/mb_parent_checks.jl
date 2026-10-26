include(joinpath(@__DIR__,"mb_estimate_checks.jl"))
@testset "parent MB freezes exploration and learns next episode" begin
 s=mb_map_state("a");p=D("method"=>"survey","action"=>"scan","priority"=>2.,"question"=>"target_observed")
 mb_parent_candidates!(s,[p],"food",nothing)
 @test p["mb_parent_estimate"]["source"]=="bootstrap"
 @test p["mb_parent_estimate"]["upper_actions"]==256
 mb_parent_begin!(s,p,"food",nothing,0);initial=deepcopy(s["parent_mb"]["active"]["food"]["estimate"])
 for i in 0:31
  mb_parent_record!(s,p,.001,i*1_000_000)
  @test mb_parent_H_increment!(s,"food","op:$(i*1_000_000):a",false,(i+1)*1_000_000)==0
 end
 # Switching the child method does not buy a fresh parent deadline.
 q=D("action"=>"walk","method"=>"step","priority"=>1.)
 mb_parent_begin!(s,q,"food",D("distance"=>2.),32_000_000)
 @test s["parent_mb"]["active"]["food"]["estimate"]==initial
 @test s["parent_mb"]["active"]["food"]["actions"]==32
 mb_parent_record!(s,q,.001,32_000_000)
 @test mb_parent_H_increment!(s,"food","op:32000000:a",true,33_000_000)==0
 @test !haskey(s["parent_mb"]["active"],"food")
 model=s["parent_mb"]["models"]["food:search"]
 @test model["samples"]==1 && model["actions_mean"]==33
 next=mb_parent_estimate!(s,D(),"food",nothing)
 @test next["source"]=="experience" && next["expected_actions"]==33
 @test initial["expected_actions"]==128
end
@testset "parent child residual is composed not added twice" begin
 s=mb_map_state("a");p=D("action"=>"scan")
 mb_parent_begin!(s,p,"food",nothing,0)
 a=s["parent_mb"]["active"]["food"]
 # No newly observed scenes for two progress windows is an explicit missed expectation.
 a["actions"]=127;mb_parent_record!(s,p,0.,0)
 @test mb_parent_H_increment!(s,"food","op:0:a",false,1_000_000;child_increment=1)==1
 @test last(s["parent_mb"]["records"])["stagnation"]==1
 @test mb_parent_H_increment!(s,"food","op:0:a",false,1_000_000;child_increment=1)==1
 @test a["child_debt"]==1 && s["parent_mb"]["H_requested"]==1
 mb_parent_record!(s,p,0.,1_000_000)
 @test mb_parent_H_increment!(s,"food","op:1000000:a",false,2_000_000)==0
 @test mb_parent_H_increment!(s,"home","op:1000000:a",false,2_000_000)===nothing
 # A late episode cannot change its own learned estimate while running.
 @test s["parent_mb"]["models"]["food:search"]["samples"]==0
 @test a["estimate"]["upper_actions"]==256
 # Bodies/other purposes may pause the food episode without charging wall time.
 @test mb_parent_H_increment!(s,"food","op:1000000:a",false,90_000_000)===nothing
 @test a["actions"]==129
end
@testset "observed approaches and MB routes supply estimates" begin
 s,p=route_fixture()
 route=mb_parent_estimate!(s,p,"home",nothing)
 approach=mb_parent_estimate!(s,D(),"home",D("distance"=>6.))
 @test route["mode"]=="route" && route["expected_actions"]==2
 @test approach["mode"]=="approach" && approach["expected_actions"]==11
 @test approach["expected_result"]=="confirmed_home"
 @test length(s["parent_mb"]["models"])==2
end
