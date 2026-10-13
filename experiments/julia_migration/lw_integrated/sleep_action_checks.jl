include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "unvalidated model admission and use" begin
 s=sleep_action_state("a");context=Any[false,false,Any[]]
 record=D("id"=>"one","actor"=>"a","executed_us"=>1,"action"=>"walk","direction"=>2,"context"=>context,"outcome"=>"blocked")
 review=D("records"=>[record],"formation_us"=>2)
 adopt_sleep_actions!(s,review,"a",3)
 adopt_sleep_actions!(s,review,"a",3)
 @test length(s["records"])==1
 record["outcome"]="performed"
 @test s["records"]["one"]["outcome"]=="blocked"
 @test_throws Exception adopt_sleep_actions!(s,review,"a",4)
 @test_throws Exception adopt_sleep_actions!(s,review,"b",4)
 @test length(s["records"])==1
 candidates=[D("method"=>"walk","action"=>"walk","direction"=>2,"priority"=>2.5,"question"=>"nearer"),D("method"=>"scan","action"=>"scan","priority"=>2.,"question"=>"observed")]
 @test choose_method!(BasicLoop("home"),deepcopy(candidates),"before")["action"]=="walk"
 @test !project_sleep_actions!(s,deepcopy(candidates),context,"a",3)
 @test !project_sleep_actions!(s,deepcopy(candidates),nothing,"a",4)
 @test !project_sleep_actions!(s,deepcopy(candidates),Any[true,false,Any[]],"a",4)
 @test project_sleep_actions!(s,candidates,context,"a",4)
 @test choose_method!(BasicLoop("home"),candidates,"after")["action"]=="scan"
 @test candidates[1]["priority"]==1.75
 @test !project_sleep_actions!(s,Any[],context,"a",5)
 move=D("food_coverage"=>"partial","visible"=>Any[],"energy"=>D("rows"=>Any[]))
 @test sleep_context(move,D("coverage"=>"complete","features"=>Any[]))===nothing
end
out=ARGS[1]
for mode in ("review","apply")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--general-sleep",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String))
 validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="apply"
  @testset "Sleep model in native loop" begin
   @test all(length(s.records)<=192 for s in values(r.sleep_action_models))
   @test all(s.adopted_us!==nothing for s in values(r.sleep_action_models))
   @test sum(s.applications for s in values(r.sleep_action_models))>0
  end
 end
end
