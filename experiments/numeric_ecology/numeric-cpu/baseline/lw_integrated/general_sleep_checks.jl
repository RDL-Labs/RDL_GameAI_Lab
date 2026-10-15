include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "finite cross-action review" begin
 s=general_sleep_state()
 remember_general!(s,"a","one","walk","blocked",nothing,"exploration",1)
 remember_general!(s,"a","two","drop","dropped",nothing,"return",2)
 remember_general!(s,"a","three","walk","blocked",nothing,"return",3)
 freeze_general!(s,"a",4)
 @test length(s["frozen"])==2
 @test s["frozen"][1]["id"]=="three"
 remember_general!(s,"a","later","climb","performed",nothing,"night",5)
 review_general!(s,"a",0,6)
 r=only(s["reviews"])
 @test r["status"]=="compared"
 @test length(r["pairs"])==1
 @test "actor" in r["pairs"][1]["matched"]
 @test "action" in r["pairs"][1]["different"]
 @test "context" in r["pairs"][1]["missing"]
 @test !any(x->x["id"]=="later",r["records"])
 review_general!(s,"a",0,7)
 @test length(s["reviews"])==1
 s["frozen"][1]["action"]="mutated"
 @test r["records"][1]["action"]=="walk"
 @test_throws Exception freeze_general!(s,"b",8)
 @test_throws Exception freeze_general!(s,"a",0)
 for i in 6:80;remember_general!(s,"a","op$i","rest","performed",nothing,"night",i);end
 @test length(s["history"])==64
 freeze_general!(s,"a",81);review_general!(s,"a",1,82)
 @test s["reviews"][2]["status"]=="insufficient_records"
 # No completed Sleep means no review; accepted final rest completes exactly once.
 s=general_sleep_state();remember_general!(s,"a","one","walk","blocked",nothing,"return",0)
 freeze_general!(s,"a",1);l=sleeper(0,REST-1_000_000)
 @test isempty(s["reviews"])
 receipt!(l,DAY-1_000_000;on_complete=(c,t)->review_general!(s,"a",0,t))
 @test length(s["reviews"])==1
 receipt!(l,DAY-1_000_000;on_complete=(c,t)->review_general!(s,"a",0,t))
 @test length(s["reviews"])==1
end
out=ARGS[1]
for mode in ("off","review")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--general-sleep",mode])
 validate_integrated(JSON3.read(read(joinpath(dir,"result.json"),String)),JSON3.read(read(joinpath(dir,"spec.json"),String)))
end
r=JSON3.read(read(joinpath(out,"review","result.json"),String))
@testset "native general Sleep boundary" begin
 @test sum(length(s.reviews) for s in values(r.general_sleep))==9
 @test all(length(s.history)<=64 for s in values(r.general_sleep))
 @test all(length(v.records)<=6 && length(v.pairs)<=15 for s in values(r.general_sleep) for v in s.reviews)
 @test all(x.executed_us<=v.formation_us<v.completed_us for s in values(r.general_sleep) for v in s.reviews for x in v.records)
end
