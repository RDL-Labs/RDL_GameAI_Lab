using Test, Serialization
include("../../src/lw/LW.jl")
const D=LW.D
function choose!(loop,source,key="route")
 LW.choose_method!(loop,[D("method"=>key,"priority"=>0.,"question"=>"local_outcome")],source)
end
@testset "bounded parent release, child evidence and replay" begin
 loop=LW.BasicLoop("test:home";probabilistic=true)
 choose!(loop,1)
 LW.resolve_method!(loop,1,false,false;goal_forecast=(13.,0.),method_forecast=(2.,0.))
 choose!(loop,2)
 LW.resolve_method!(loop,2,true,true;goal_forecast=(0.,0.),goal_release=8.)
 @test loop.H==5 # Only 8 belongs to this completed journey.
 @test loop.methods["route"].H==2 # Parent success is not child forecast evidence.
 @test loop.methods["route"].reward≈8.1
 @test last(loop.events).H_released==8
 @test !LW.resolve_method!(loop,2,true,true;goal_forecast=(0.,0.),goal_release=8.)
 @test loop.H==5
 io=IOBuffer();serialize(io,loop);seekstart(io);restored=deserialize(io)
 @test !LW.resolve_method!(restored,2,true,true;goal_forecast=(0.,0.),goal_release=8.)
 choose!(loop,3)
 LW.resolve_method!(loop,3,true,false;method_forecast=(0.,2.))
 @test loop.H==5
 @test loop.methods["route"].H==0
 @test last(loop.events).method_reward==0
 @test loop.forecast_balances[nothing]["released_total"]==8
 choose!(loop,4)
 @test_throws Exception LW.resolve_method!(loop,4,true,false;goal_release=5.)
 @test loop.H==5
end
@testset "actual parent episode determines releasable amount" begin
 map=LW.mb_map_state("a");p=D("action"=>"scan")
 LW.mb_parent_begin!(map,p,"food",nothing,0)
 active=map["parent_mb"]["active"]["food"];active["actions"]=127
 LW.mb_parent_record!(map,p,0.,0)
 charged=LW.mb_parent_H_increment!(map,"food","op:0:a",false,1_000_000)
 @test charged>0
 @test LW.mb_parent_release(map,"food","op:0:a",1_000_000)===nothing
 LW.mb_parent_record!(map,p,0.,1_000_000)
 LW.mb_parent_H_increment!(map,"food","op:1000000:a",true,2_000_000)
 @test LW.mb_parent_release(map,"food","op:1000000:a",2_000_000)==charged
 @test LW.mb_parent_release(map,"home","op:1000000:a",2_000_000)===nothing
 @test LW.mb_parent_release(map,"food","op:0:a",2_000_000)===nothing
 # The original journey may be suspended while the same goal is approached.
 suspended=D("applied_H"=>3.)
 map["parent_mb"]["modes"]=D("food"=>D("suspended"=>suspended))
 LW.mb_parent_begin!(map,p,"food",nothing,2_000_000)
 LW.mb_parent_record!(map,p,0.,2_000_000)
 LW.mb_parent_H_increment!(map,"food","op:2000000:a",true,3_000_000)
 @test LW.mb_parent_release(map,"food","op:2000000:a",3_000_000)==3
 LW.mb_parent_begin!(map,p,"food",nothing,3_000_000)
 LW.mb_parent_record!(map,p,0.,3_000_000)
 LW.mb_parent_H_increment!(map,"food","op:3000000:a",true,4_000_000)
 @test LW.mb_parent_release(map,"food","op:3000000:a",4_000_000)==0
end
@testset "one catch and one trade leave unmet differences" begin
 map=LW.mb_map_state("a")
 LW.acquisition_result!(map,"fishing",1,100.,200.,false;now=1)
 LW.acquisition_result!(map,"fishing",1,100.,0.,true;now=2)
 state=map["acquisition"];site=state["sites"]["fishing:1"]
 @test site["H"]==1
 @test site["reward"]≈1.1
 saved=deepcopy(state)
 LW.acquisition_publish!(state,state["trials"][end];achieved=true)
 @test saved==state
 loop=LW.BasicLoop("test:trade";probabilistic=true)
 choose!(loop,1,"offer")
 LW.resolve_prediction!(loop,1,2.,0.;tolerance=0.)
 choose!(loop,2,"offer")
 LW.resolve_prediction!(loop,2,0.,1.;fulfilled=true,tolerance=0.)
 @test loop.H==1 && loop.methods["offer"].H==1
 @test loop.methods["offer"].reward≈1.1 # Parent/child relief is not paid twice.
 @test !LW.resolve_prediction!(loop,2,0.,1.;fulfilled=true,tolerance=0.)
 @test loop.methods["offer"].reward≈1.1
end
@testset "arrival mode cannot overwrite modern H ledger" begin
 map=LW.mb_map_state("a");map["goal_arrival"]=D("home"=>LW.goal_arrival_state())
 loop=LW.BasicLoop("test:home";probabilistic=true)
 LW.loop_forecast_difference!(loop,nothing,7.,0.)
 arrival=map["goal_arrival"]["home"];arrival["mode"]="approach";arrival["entries"]=1
 LW.mb_parent_arrival_sync!(map,loop,"home",1)
 @test loop.H==7 && loop.forecast_balances[nothing]["H"]==7
 arrival["mode"]="search"
 LW.mb_parent_arrival_sync!(map,loop,"home",2)
 @test loop.H==7 && loop.forecast_balances[nothing]["H"]==7
 choose!(loop,3)
 LW.resolve_method!(loop,3,true,true;goal_release=7.)
 @test loop.H==0
 LW.loop_forecast_difference!(loop,nothing,0.,0.)
 @test loop.H==0 # Released H must not return from an older ledger.
end
