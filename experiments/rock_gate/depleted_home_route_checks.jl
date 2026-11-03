using Test, JSON3
include("../julia_migration/lw_integrated/mb_goal_cue_checks.jl")
@testset "depleted site retains home cue and directed return" begin
 s,pool,p=goal_cue_fixture();now=3_000_000
 home=only(values(s["chunks"]));home["food_ref"]=7
 # Controlled fixture: the same observed place has both food and home relations.
 food=deepcopy(home);food["goal"]="food";s["chunks"]["food:fixture"]=food
 mb_food_site_observe!(s,7,1,now,"harvest_contact")
 geometry=deepcopy(s["edges"]);credit=deepcopy(home)
 cue_before=only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,now))
 food_before=only(mb_goal_cue_project!(s,[copy(p)],pool,"food",8,now))
 path_before=only(mb_chunk_candidates!(s,move,"home",90.,0.,now;H=8))
 outlook_before=deepcopy(mb_return_estimate(s,mb_return_outlook!(s,now),s["current"].key))
 @test outlook_before!==nothing && length(outlook_before["path"])==2
 mb_food_site_observe!(s,7,0,now,"harvest_contact")
 cue_after=only(mb_goal_cue_project!(s,[copy(p)],pool,"home",8,now))
 food_after=only(mb_goal_cue_project!(s,[copy(p)],pool,"food",8,now))
 path_after=only(mb_chunk_candidates!(s,move,"home",90.,0.,now;H=8))
 @test cue_after["priority"]==cue_before["priority"]
 @test cue_after["mb_goal_cue"]==cue_before["mb_goal_cue"]
 @test cue_after["priority"]>p["priority"]
 @test food_after["mb_goal_cue"]["strength"]≈.25food_before["mb_goal_cue"]["strength"]
 @test path_after["priority"]==path_before["priority"]
 @test path_after["mb_path"]==path_before["mb_path"]
 s["return_outlook"]["next_us"]=0 # Rebuild rather than merely reading old cache.
 @test mb_return_estimate(s,mb_return_outlook!(s,now),s["current"].key)==outlook_before
 @test s["edges"]==geometry && home==credit
 mb_goal_cue_selected!(s,cue_after,now)
 @test last(s["goal_cues"]["records"])["goal"]=="home"
 # Execute the same two learned transitions after depletion and complete home.
 id=path_after["mb_route"]
 mb_record!(s,merge(path_after,D("purpose_family"=>"home")),"performed",.01,now)
 mb_observe!(s,chunk_view(now+1_000_000,"mid"),now+1_000_000)
 q=only(mb_route_candidates!(s,move,"home",90.,0.,now+1_000_000))
 @test q["mb_route"]==id && q["mb_edge"]==path_after["mb_path"][2]
 mb_record!(s,merge(q,D("purpose_family"=>"home")),"performed",.01,now+1_000_000)
 mb_observe!(s,chunk_view(now+2_000_000,"near"),now+2_000_000;home=true)
 mb_route_goal!(s,"home","op:4000000:a",true,8,0,now+2_000_000)
 @test s["routes"]["active"]===nothing
 @test s["routes"]["stats"][id]["success"]==1
 @test mb_food_site_empty(s,7) # Returning does not replenish remembered food.
 println("DEPLETED_HOME ",JSON3.write(D("home_cue_priority"=>[cue_before["priority"],cue_after["priority"]],
   "food_cue_strength"=>[food_before["mb_goal_cue"]["strength"],food_after["mb_goal_cue"]["strength"]],
   "home_route_priority"=>[path_before["priority"],path_after["priority"]],"steps"=>2,"home_success"=>true)))
end
