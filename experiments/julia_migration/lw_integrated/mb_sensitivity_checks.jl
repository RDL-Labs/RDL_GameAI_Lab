include(joinpath(@__DIR__,"mb_local_repair_checks.jl"))
@testset "continuous residual and separate sensitivity" begin
 s=mb_map_state("a";sensitivity=D("stagnation"=>.5,"energy"=>2.))
 @test mb_response(s,"stagnation",.25)==.125
 @test mb_response(s,"energy",.25)==.5
 @test mb_response(s,"delay",-1)==0
 @test_throws ErrorException mb_map_state("a";sensitivity=D("delay"=>NaN))
 @test_throws ErrorException mb_map_state("a";sensitivity=D("unknown"=>1.))
 p=D("action"=>"scan");mb_parent_begin!(s,p,"food",nothing,0)
 a=s["parent_mb"]["active"]["food"];a["actions"]=64
 mb_parent_record!(s,p,0.,0)
 inc=mb_parent_H_increment!(s,"food","op:0:a",false,1_000_000)
 @test inc≈.5/64
 @test mb_parent_H_increment!(s,"food","op:0:a",false,1_000_000)==inc
 @test s["parent_mb"]["H_requested"]==inc
 loop=BasicLoop("food";probabilistic=true)
 c=[D("method"=>"scan","priority"=>1.,"question"=>"target_observed")]
 choose_method!(loop,c,"fraction")
 resolve_method!(loop,"fraction",nothing,false;goal_H_increment=inc)
 @test loop.H==inc
 @test loop.methods["scan"].reward==0
 @test_throws ErrorException resolve_method!(loop,"nan",false,false;goal_H_increment=NaN)
 @test_throws ErrorException resolve_method!(loop,"inf",false,false;goal_H_increment=Inf)
 choose_method!(loop,c,"done")
 resolve_method!(loop,"done",true,true;goal_H_increment=0.)
 @test loop.H==0 && loop.methods["scan"].reward==inc
 # Child pressure is already sensitivity-scaled: do not scale it again at the parent.
 s=mb_map_state("a";sensitivity=D("delay"=>2.));mb_parent_begin!(s,p,"food",nothing,0)
 mb_parent_record!(s,p,0.,0)
 @test mb_parent_H_increment!(s,"food","op:0:a",false,1_000_000;child_increment=.25)==.25
 # Fractional energy overshoot survives into route pressure.
 s,p=route_fixture();s["sensitivity"]["energy"]=.5
 mb_record!(s,p,"performed",.035,3_000_000)
 mb_observe!(s,chunk_view(4_000_000,"mid"),4_000_000)
 @test mb_route_H_increment!(s,"home","op:3000000:a",false,4_000_000)≈.25
end

@testset "integrated forecast handoff preserves zero residual" begin
 for increment in (0,0.0,-0.0)
  loop=BasicLoop("home";probabilistic=true);loop.H=2.5
  c=[D("method"=>"walk","priority"=>1.,"question"=>"target_observed")]
  choose_method!(loop,c,"within")
  loop.methods["walk"].H=.5
  evidence=forecast_method_evidence(increment,false,true,false)
  @test evidence===nothing
  resolve_method!(loop,"within",evidence,false;goal_H_increment=increment)
  @test loop.H==2.5 && loop.methods["walk"].H==.5
  @test loop.methods["walk"].failure_count==0 && loop.methods["walk"].reward==0
 end
 @test forecast_method_evidence(nothing,false,true,false)===false
 @test forecast_method_evidence(.01,false,true,false)===false
 @test forecast_method_evidence(.01,false,false,false)===nothing
 @test forecast_method_evidence(0.,true,true,true)===true
end
