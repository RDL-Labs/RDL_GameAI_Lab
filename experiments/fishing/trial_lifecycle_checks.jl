using Test, Serialization
include("../../src/lw/LW.jl")
@testset "shared trial terminal states and receipts" begin
 for status in ("achieved","failed","interrupted","handed_off")
  trial=LW.action_trial(1,"test","local_goal",10.)
  @test LW.action_trial_step!(trial,12.,2.;now=1)
  @test !LW.action_trial_step!(trial,12.,2.;now=1)
  @test trial["elapsed"]==12 && trial["energy"]==2 && trial["H"]==.2
  @test LW.action_trial_close!(trial,status,"observed")
  @test !LW.action_trial_step!(trial,1.,1.;now=2)
  @test !LW.action_trial_close!(trial,"achieved","again")
 end
end
@testset "exploration discovery closes locally and hands off" begin
 map=LW.mb_map_state(first(LW.IDS));parent_before=deepcopy(map["parent_mb"])
 known=LW.D("ref"=>1,"acquisition"=>"pickup")
 LW.acquisition_begin!(map,"explore",nothing,100.;observed_keys=["pickup:1"])
 LW.acquisition_result!(map,"explore",nothing,100.,150.,false;now=1)
 @test LW.acquisition_key("explore",nothing)==LW.acquisition_key("explore","unknown")
 @test !LW.acquisition_observe!(map,[known])
 @test LW.acquisition_value(map,"explore","unknown",100.,1.,0.).local_H==.5
 novel=LW.D("ref"=>2,"acquisition"=>"pickup")
 @test LW.acquisition_observe!(map,[known,novel])
 state=map["acquisition"]
 @test state["methods"]["explore"]["completed"]==1
 @test state["methods"]["explore"]["H"]==0
 @test map["parent_mb"]==parent_before
 @test !LW.acquisition_observe!(map,[novel])
 successor=LW.acquisition_begin!(map,"pickup",2,10.)
 @test successor["predecessor"]==1 && successor["elapsed"]==0
 LW.acquisition_result!(map,"pickup",2,999.,1.,true;now=2)
 @test state["sites"]["pickup:2"]["forecast"]==10
 LW.acquisition_result!(map,"pickup",2,999.,1.,true;now=2)
 @test state["methods"]["pickup"]["completed"]==1
 @test state["methods"]["explore"]["completed"]==1
 @test map["parent_mb"]==parent_before
 LW.acquisition_result!(map,"explore",nothing,20.,30.,false;now=3)
 @test LW.acquisition_finish!(map,"interrupted","sleep")
 @test state["choice"]===nothing && state["active"]===nothing
 LW.acquisition_result!(map,"explore",nothing,40.,1.,false;now=4)
 @test state["active"]["elapsed"]==1 && state["active"]["forecast"]==40
 io=IOBuffer();serialize(io,map);seekstart(io);restored=deserialize(io)
 @test restored["acquisition"]==state
end
@testset "H changes confidence, not time; shared evidence counted once" begin
 map=LW.D("acquisition"=>LW.acquisition_state());state=map["acquisition"]
 state["choice"]=LW.D("technique"=>"explore","ref"=>nothing,"seconds"=>100.,"uncertainty"=>1.)
 security=LW.D("estimate"=>LW.D("metabolic_rate"=>.001,"search_seconds"=>200.),"supplied"=>0.)
 body=LW.Body(10.,0.,90.,0.)
 baseline=LW.food_self_reliance(security,map,body)
 for table in (state["methods"],state["sites"])
  table[table===state["methods"] ? "explore" : "explore:unknown"]=LW.D("H"=>1000.)
 end
 updated=LW.food_self_reliance(security,map,body)
 @test updated["seconds"]==baseline["seconds"]==200
 @test updated["failure"]==1000
 @test updated["confidence"]<baseline["confidence"]
 value=LW.acquisition_value(map,"explore",nothing,100.,1.,4.)
 @test value.method_repulsion==0 && value.local_repulsion==log1p(1000.)
end
@testset "candidate consideration is not execution; observed handoff uses shared lifecycle" begin
 map=LW.mb_map_state(first(LW.IDS));loop=LW.BasicLoop("trial-selection";probabilistic=true,seed=1)
 LW.acquisition_targets!(map,Any[],loop,0)
 @test map["acquisition"]["active"]===nothing
 @test isempty(map["acquisition"]["trials"])
 @test !LW.acquisition_finish!(map,"interrupted","home_comparison_only")
 choice=map["acquisition"]["choice"]
 LW.acquisition_result!(map,choice["technique"],choice["ref"],choice["seconds"],1.,false;now=1)
 @test map["acquisition"]["active"]["elapsed"]==1
 visible=Any[LW.D("ref"=>7,"distance"=>5.,"appearance"=>"red_round_fruit")]
 LW.acquisition_targets!(map,visible,loop,2)
 @test map["acquisition"]["methods"]["explore"]["completed"]==1
 @test last(map["acquisition"]["trials"])["evidence"]["ref"]==7
end
