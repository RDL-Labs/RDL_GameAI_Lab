include("mb_recognition_checks.jl")
@testset "strong relations first, pressure and weak-fit expansion" begin
 s=mb_map_state("a");mb_observe!(s,recognition_view(0),0)
 empty!(s["nodes"])
 for i in 1:40
     key=lpad(string(i),2,'0')
     s["nodes"][key]=D("signature"=>"brown:far:0|gray:far:2","home"=>false,"food"=>false)
 end
 # Put a learned relation at the end of lexical order: it must still be examined first.
 id=s["current"].key*":40"
 s["recognition"]["associations"][id]=D("matches"=>20,"mismatches"=>0)
 low=mb_correspondences(s,keys(s["nodes"]),0;H=0)
 @test first(low)["key"]=="40"
 @test last(s["recognition"]["retrieval"]["records"])["examined"]==8
 high=mb_correspondences(s,keys(s["nodes"]),0;H=8)
 @test last(s["recognition"]["retrieval"]["records"])["examined"]==40
 @test length(high)==8 && length(low)==4
 @test sum(x["probability"] for x in high)≈1
 # Evidence weakens priority immediately, without a stale retrieval cache.
 s["recognition"]["associations"][id]["mismatches"]=200
 @test all(x["key"]!="40" for x in mb_correspondences(s,keys(s["nodes"]),0;H=0))
 for node in values(s["nodes"])
     node["signature"]="brown:near:0|gray:near:2";delete!(node,"features")
 end
 mb_correspondences(s,keys(s["nodes"]),0;H=0)
 r=last(s["recognition"]["retrieval"]["records"])
 @test r["examined"]==40 && r["batches"]==5
 @test r["best_weight"]<.25
 @test isempty(mb_correspondences(s,["deleted"],0))
 @test length(s["nodes"])==40 # Retrieval does not merge memories.
end
