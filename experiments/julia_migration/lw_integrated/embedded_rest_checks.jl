include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "embedded rest prior, bodily competition and experience" begin
 day=17280_000_000;rng=Xoshiro(41)
 s=embedded_rest_state()
 @test s["place"]=="home" && s["place_value"]==.8 && isempty(s["experience"])
 @test !embedded_rest_request!(s,0.,100.,0.,false,false,0,day,rng)
 @test s["probability"]==0
 embedded_rest_request!(s,.5,100.,0.,false,false,1,day,rng);half=s["probability"]
 embedded_rest_request!(s,1.,100.,0.,false,false,2,day,rng);full=s["probability"]
 @test 0<half<full<1 && full>.99
 @test !embedded_rest_request!(s,1.,10.,1.,true,false,3,day,rng)
 @test !s["requested"] && s["food_blocks"]==1 && s["probability"]<full
 @test embedded_rest_request!(s,0.,100.,0.,false,true,4,day,rng)
 # Rest anywhere reduces the bodily proxy; location preference is learned only at home.
 for i in 0:59;embedded_rest_feedback!(s,false,"walk","performed",i*1_000_000,day);end
 @test s["awake_seconds"]==60 && isempty(s["experience"])
 embedded_rest_feedback!(s,false,"rest","performed",60_000_000,day)
 @test s["awake_seconds"]==56
 embedded_rest_feedback!(s,false,"rest","performed",60_000_000,day)
 @test s["awake_seconds"]==56
 for (action,expected) in (("rest",5/6),("run",4/6))
  state=embedded_rest_state();state["requested"]=true
  for i in 0:59;embedded_rest_feedback!(state,true,action,"performed",i*1_000_000,day);end
  @test state["place_value"]≈expected
  @test length(state["experience"])==1
 end
 state=embedded_rest_state();state["requested"]=true
 for i in 0:3899;embedded_rest_feedback!(state,true,"run","performed",i*1_000_000,day);end
 @test length(state["experience"])==64 && state["place_value"]<.1
 @test all(!haskey(state,k) for k in ("x","z","path","home_coordinates"))
 for i in 1:5000;embedded_rest_request!(state,.5,90.,0.,false,false,i,day,rng);end
 @test length(state["records"])<=64
end
