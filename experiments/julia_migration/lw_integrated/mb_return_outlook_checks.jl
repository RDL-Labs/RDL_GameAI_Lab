include(joinpath(@__DIR__,"mb_completion_reward_checks.jl"))
@testset "exploration keeps directed return outlook" begin
 s,p=route_fixture();now=3_000_000
 before=deepcopy(s["edges"])
 state=mb_return_outlook!(s,now)
 r=mb_return_estimate(s,state,s["current"].key)
 @test r!==nothing && length(r["path"])==2
 @test s["edges"]==before
 @test r["energy"]≈.02
 @test mb_return_outlook!(s,now+1)["builds"]==1
 cs=[D("method"=>"explore","action"=>"walk","direction"=>0,"priority"=>1.),
     D("method"=>"look","action"=>"scan","priority"=>1.)]
 mb_parent_candidates!(s,cs,"food",nothing)
 mb_project_return!(s,cs,move,"food",90.,now)
 @test any(get(x,"mb_return_link",false) for x in cs)
 @test first(cs)["mb_return_outlook"]["status"]=="observed_chain"
 @test first(cs)["mb_parent_estimate"]["return_home"]["margin"]>0
 link=only(filter(x->get(x,"mb_return_link",false),cs))
 @test !haskey(link,"mb_route_goal") # Exploration is not silently changed to return.
 @test length(state["records"])==1
 @test haskey(s["edges"],link["mb_edge"])
 frozen=deepcopy(cs)
 @test mb_project_return!(s,cs,move,"home",90.,now)==frozen
 low=deepcopy(frozen);mb_project_return!(s,low,move,"food",1.,now)
 @test first(low)["mb_return_outlook"]["pressure"]>first(cs)["mb_return_outlook"]["pressure"]
 # Deleting any edge invalidates cached reachability; no invented reverse connection.
 delete!(s["edges"],last(r["path"]))
 @test mb_return_estimate(s,state,s["current"].key)===nothing
 s,p=route_fixture()
 for n in values(s["nodes"]);n["home"]=false;end
 s["nodes"][s["current"].key]["home"]=true
 state=mb_return_outlook!(s,now)
 endpoint=s["edges"][last(p["mb_path"] )]["to"]
 @test mb_return_estimate(s,state,endpoint)===nothing
 @test length(state["paths"])<=256
 @test all(length(x["path"])<=32 for x in values(state["paths"]))
 # Unknown does not remove movement options; missing home evidence stays explicit.
 for n in values(s["nodes"]);n["home"]=false;end
 state["next_us"]=0
 options=[D("method"=>"walk","action"=>"walk","direction"=>0,"priority"=>1.),
          D("method"=>"scan","action"=>"scan","priority"=>1.)]
 mb_project_return!(s,options,move,"food",90.,now)
 @test length(options)==2
 @test all(x["mb_return_outlook"]["status"]=="unconfirmed" for x in options)
 @test options[2]["priority"]>options[1]["priority"]
 @test all(x["mb_return_outlook"]["energy"]===nothing for x in options)
 s["current"]=nothing
 @test mb_project_return!(s,cs,move,"food",90.,now)==cs
end
