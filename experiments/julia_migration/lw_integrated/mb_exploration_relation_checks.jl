include("mb_goal_cue_checks.jl")
@testset "outbound cue relation exists before return success" begin
 s=mb_map_state("a";chunks=true);s["exploration_relations_enabled"]=true
 view=chunk_view(0,"far");view["features"][1]["distance"]=5.
 mb_observe!(s,view,0;home=true)
 p=D("action"=>"walk","direction"=>2,"purpose_family"=>"food","cue_kind"=>"shape",
     "cue_label"=>"brown","cue_angle"=>0.,"cue_distance"=>5.,"priority"=>2.5,"method"=>"cue:test")
 edges=length(s["edges"]);credits=s["chunk_goal_credits"]
 mb_record!(s,p,"performed",.01,0;turn=0.,distance=.5)
 r=s["exploration_relations"];l=only(values(r["links"]))
 @test l["predicted_strength"]==.5 && l["support"]==0
 @test length(s["edges"])==edges && s["chunk_goal_credits"]==credits
 q=only(mb_exploration_project!(s,[copy(p)],"home",8,0))
 @test q["priority"]>p["priority"] && !haskey(q,"mb_path")
 @test only(mb_exploration_project!(s,[copy(p)],"food",8,0))["priority"]==p["priority"]
 next=chunk_view(1_000_000,"mid");next["features"][1]["distance"]=4.5
 mb_observe!(s,next,1_000_000)
 @test l["support"]>0 && l["approach_evidence"]>0
 @test 0<l["arrival_evidence"]<1
 @test 0<r["scenes"][s["current"].key]<1
 @test s["chunk_goal_credits"]==0 && isempty(s["chunks"])
 @test all(e["from"]!=s["current"].key for e in values(s["edges"])) # No reverse edge.
 # A second target inherits the experienced connection, without new home sight.
 p2=merge(p,D("cue_label"=>"gray","cue_angle"=>45.,"cue_distance"=>20.))
 mb_record!(s,p2,"blocked",.01,1_000_000;distance=0.)
 second=r["links"][s["current"].key*":gray"]
 @test 0<second["origin_home_strength"]<1
 next["source"]="ob:2000000:a";mb_observe!(s,next,2_000_000)
 @test second["failures"]==1 && second["support"]==0
 # Unknown scenes do not receive a fabricated home origin.
 u=mb_map_state("a");u["exploration_relations_enabled"]=true
 mb_observe!(u,view,0);mb_record!(u,p,"performed",.01,0)
 @test isempty(u["exploration_relations"]["links"])
 # Missing feature is unknown, and replaying an observation cannot add evidence twice.
 mb_record!(s,merge(p,D("cue_distance"=>4.5)),"performed",.01,2_000_000;distance=.5)
 unknown=chunk_view(3_000_000,"mid");unknown["features"]=unknown["features"][2:2]
 mb_observe!(s,unknown,3_000_000);n=r["missing"]
 @test n==1
 mb_observe!(s,unknown,3_000_000)
 @test r["missing"]==n
end
