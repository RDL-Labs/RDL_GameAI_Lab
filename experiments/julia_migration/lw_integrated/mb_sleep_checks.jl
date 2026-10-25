include("mb_map_checks.jl")
@testset "shared sleep search without imagined reward" begin
 s=mb_map_state("a";chunks=true)
 mb_observe!(s,sceneview(0,("far","far")),0);mb_record!(s,walk,"performed",.02,0)
 mb_observe!(s,sceneview(1_000_000,("mid","far")),1_000_000);mb_record!(s,walk,"performed",.03,1_000_000)
 mb_observe!(s,sceneview(2_000_000,("near","mid")),2_000_000;home=true)
 before=deepcopy(s["edges"])
 mb_sleep_freeze!(s,2_000_000)
 # Waking mutations after freezing cannot create a sleeping search result.
 for n in values(s["nodes"]);n["food"]=true;end
 mb_sleep_review!(s,0,3_000_000)
 @test length(s["sleep"]["reviews"])==1
 @test last(s["sleep"]["reviews"])["searches"]==6
 @test last(s["sleep"]["reviews"])["expanded"]<=6*64
 @test length(s["sleep"]["hypotheses"])==2
 @test all(h["goal"]=="home" for h in values(s["sleep"]["hypotheses"]))
 @test s["edges"]==before && s["chunk_reward"]==0 && isempty(s["chunks"])
 mb_sleep_review!(s,0,4_000_000)
 @test length(s["sleep"]["reviews"])==1
 mb_observe!(s,sceneview(4_000_000,("far","far")),4_000_000)
 p=mb_sleep_candidates!(s,move,"home",4,2,90.,0.,4_000_000)
 @test length(p)==1 && only(p)["mb_depth"]==2
 waking=mb_simulate!(s,move,"home",4,2,90.,0.,4_000_000)
 @test only(p)["method"]==only(waking)["method"] && only(p)["priority"]==only(waking)["priority"]
 @test isempty(mb_sleep_candidates!(s,move,"home",0,2,90.,0.,4_000_000))
 @test isempty(mb_sleep_candidates!(s,move,"home",4,2,10.,0.,4_000_000))
 mb_record!(s,only(p),"performed",.02,4_000_000)
 mb_observe!(s,sceneview(5_000_000,("mid","far")),5_000_000)
 @test s["sleep"]["selected"]==1 && s["prediction_match"]==1 && s["chunk_reward"]==0
 empty!(s["edges"])
 @test isempty(mb_sleep_candidates!(s,move,"home",4,2,90.,0.,5_000_000))
end
