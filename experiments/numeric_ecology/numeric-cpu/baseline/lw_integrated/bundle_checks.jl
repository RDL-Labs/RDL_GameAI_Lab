include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "conjunction formation use dormancy and wake" begin
 s=bundle_state("a");h=hunger_state("a");h["comparisons"]=1;h["H"]=2
 ctx=Any["none","complete",false,"complete",false,true,false]
 r=D("actor"=>"a","operation"=>"op1","capture_us"=>0,"executed_us"=>1_000_000,"context"=>ctx,"phase"=>"exploration","action"=>"walk","outcome"=>"blocked")
 remember_bundle!(s,r);form_bundle!(s,h,1_000_000)
 @test isempty(s["active"])
 h["comparisons"]=2;form_bundle!(s,h,2_000_000)
 @test length(s["active"])==1 && length(s["used"])==1
 r["context"][1]="many"
 @test s["active"][1]["sources"][1]["context"][1]=="none"
 h["comparisons"]=3;form_bundle!(s,h,3_000_000)
 @test length(s["active"])==1
 context=copy(s["active"][1]["sources"][1]["context"])
 cs=[D("method"=>"walk","action"=>"walk","priority"=>2.,"question"=>"movement_progress"),D("method"=>"scan","action"=>"scan","priority"=>1.5,"question"=>"target_observed")]
 trace=project_bundles!(s,cs,BasicLoop("food"),context,"exploration",3_000_000)
 @test trace["changed"] && trace["selected"]=="scan"
 use_bundles!(s,trace,"scan","performed")
 @test s["changes"]==1 && first(values(s["usage"]))["uses"]==1
 sleep_bundles!(s,1,4_000_000)
 @test length(s["active"])==1
 for day in 2:4;sleep_bundles!(s,day,day*5_000_000);end
 @test isempty(s["active"]) && length(s["dormant"])==1
 old=deepcopy(s);sleep_bundles!(s,4,20_000_000);@test s==old
 wake_bundles!(s,context,"night");@test isempty(s["active"])
 wake_bundles!(s,context,"exploration")
 @test length(s["active"])==1 && s["woken"]==1 && isempty(s["dormant"])
 @test_throws Exception remember_bundle!(s,merge(r,D("actor"=>"b")))
 @test_throws Exception form_bundle!(s,hunger_state("b"),9_000_000)
 @test project_bundles!(s,cs,BasicLoop("food"),context,"safety",9_000_000)===nothing
 snapshot=bundle_snapshot(s);empty!(snapshot["active"]);@test length(s["active"])==1
end
for mode in ("off","on")
 dir=joinpath(ARGS[1],mode)
 native_main([dir,"--days","4","--seed","20261005","--food","renewable","--food-body","on","--general-sleep","apply","--sleep-retention","strata","--experience-bundles",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "living conjunctions" begin
   @test sum(s.sequence for s in values(r.experience_bundles))>0
   @test all(length(s.active)<=32 && length(s.active)+length(s.dormant)<=256 && length(s.history)<=8 for s in values(r.experience_bundles))
   @test all(length(s.used)==length(unique(s.used)) for s in values(r.experience_bundles))
  end
 end
end
