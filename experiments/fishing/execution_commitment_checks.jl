using Test, Serialization
include("../../integrations/lightweight_julia/native.jl")
@testset "shared execution review reasons" begin
 c=execution_commitment("food",0,100.;context=(0,"explore"),pressure=2.)
 @test execution_review_reason(c,99_000_000)===nothing
 @test execution_review_reason(c,100_000_000)=="forecast_elapsed"
 @test execution_review_reason(c,1;key="home")=="scope_changed"
 @test execution_review_reason(c,1;context=(1,"explore"))=="evidence_changed"
 @test execution_review_reason(c,1;pressure=3.)=="pressure_increased"
 @test execution_review_reason(c,1;pressure=1.)===nothing
 @test execution_review_reason(c,1;contradiction=true)=="contradicted"
 @test execution_review_reason(c,1;interrupted=true)=="interrupted"
 @test execution_review_reason(c,1;completed=true)=="completed"
 io=IOBuffer();serialize(io,c);seekstart(io)
 @test execution_review_reason(deserialize(io),99_000_000)===nothing
end
@testset "pickup and fishing share retention and empty-site evidence" begin
 for technique in ("pickup","fishing")
  map=mb_map_state("test");loop=BasicLoop("food";probabilistic=true)
  a=get!(acquisition_state,map,"acquisition")
  a["choice"]=D("method"=>technique*":2","technique"=>technique,"ref"=>2,"selected_us"=>0,
    "execution"=>execution_commitment(technique*":2",0,100.))
  a["next_us"]=100_000_000
  @test isempty(acquisition_targets!(map,Any[],loop,65_000_000))
  @test a["choice"]["ref"]==2
  mb_food_site_observe!(map,2,0,66_000_000,"visible_empty")
  acquisition_targets!(map,Any[],loop,66_000_000)
  @test last(a["records"])["review_reason"]=="contradicted"
  @test a["choice"]["technique"]=="explore"
  # Selected but not yet stepped plans also end on a parent change.
  a["active"]=nothing
  acquisition_finish!(map,"interrupted","parent_purpose_changed")
  @test a["choice"]===nothing
 end
end
@testset "parent selection ignores known-source visibility fluctuations" begin
 s=mb_map_state("test");s["daily_plan"]=mb_daily_plan_state("test",9)
 mb_plan_context!(s,0,600_000_000,70.,0.)
 source=D("ref"=>2,"distance"=>5.,"acquisition"=>"pickup")
 move=D("visible"=>Any[source])
 mb_daily_request!(s,move,nothing,false,0,70.,0.,0,600_000_000)
 a=s["daily_plan"]["active"]
 # Test a known unchanged choice with a longer frozen estimate.
 a["execution"]["review_us"]=500_000_000
 original=deepcopy(a["execution"]);count=length(s["daily_plan"]["decisions"])
 for (now,v) in ((65_000_000,Any[]),(130_000_000,Any[source]),(195_000_000,Any[]))
  mb_daily_request!(s,D("visible"=>v),nothing,false,0,70.,0.,now,600_000_000)
 end
 @test length(s["daily_plan"]["decisions"])==count
 @test a["execution"]==original
 mb_daily_request!(s,move,nothing,false,1,70.,0.,260_000_000,600_000_000)
 @test length(s["daily_plan"]["decisions"])==count+1
 @test last(s["daily_plan"]["decisions"])["review_reason"]=="evidence_changed"
end
