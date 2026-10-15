include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "actual use and whole episode credit" begin
 s=selection_trail_state("a");ctx=Any["none"];loop=BasicLoop("food")
 candidates()=[D("method"=>"walk","action"=>"walk","direction"=>2,"priority"=>1.,"question"=>"movement_progress"),D("method"=>"scan","action"=>"scan","priority"=>1.5,"question"=>"target_observed")]
 trace=project_trails!(s,candidates(),loop,ctx,"exploration")
 @test !use_trail!(s,"a","bad",trace,"walk","expired",60.,4,String[])
 @test isempty(s["edges"])
 for i in 1:30;use_trail!(s,"a","op$i",trace,"walk","performed",60.,4,["bundle1"]);end
 @test first(values(s["edges"]))["uses"]==30
 @test !use_trail!(s,"a","op30",trace,"walk","performed",60.,4,String[])
 @test project_trails!(s,candidates(),loop,ctx,"exploration")["selected"]=="walk"
 @test !resolve_trail!(s,"a",80.,"still-hungry",100_000_000)
 @test s["episode"]!==nothing
 @test resolve_trail!(s,"a",90.,"sufficient",200_000_000)
 @test first(values(s["edges"]))["success_credit"]==5.
 @test length(s["completed"])==1 && s["episode"]===nothing
 @test !resolve_trail!(s,"a",90.,"again",201_000_000)
 @test project_trails!(s,candidates(),loop,ctx,"safety")===nothing
 @test_throws Exception resolve_trail!(s,"b",90.,"wrong",202_000_000)
 @test length(first(values(first(s["completed"])["edges"]))["bundle_refs"])==1
end
for mode in ("off","on")
 dir=joinpath(ARGS[1],mode)
 native_main([dir,"--days","4","--seed","20261005","--food","renewable","--food-body","on","--general-sleep","apply","--sleep-retention","strata","--experience-bundles","on","--bundle-credit","on","--selection-trails",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "living selection trails" begin
   @test sum(length(s.edges) for s in values(r.selection_trails))>0
   @test all(length(s.edges)<=512 for s in values(r.selection_trails))
   @test all(all(0<=e.success_credit<=8 for e in values(s.edges)) for s in values(r.selection_trails))
  end
 end
end
