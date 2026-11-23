using Test,Serialization
include("../../src/lw/LW.jl")
@testset "source before route" begin
 m=LW.mb_map_state(first(LW.IDS);chunks=true)
 c=LW.D("goal"=>"food","food_ref"=>7,"to"=>"goal","successes"=>2,"reward"=>1.,"misses"=>0,"edges"=>String[])
 m["chunks"]["a"]=c;m["chunks"]["b"]=copy(c)
 @test length(LW.food_goal_sources(m,Any[]))==1
 @test isempty(LW.food_goal_sources(m,[LW.D("ref"=>7)]))
 loop=LW.BasicLoop("test";probabilistic=true)
 LW.acquisition_targets!(m,Any[],loop,0)
 rows=last(m["acquisition"]["records"])["candidates"]
 @test count(r->r["ref"]==7,rows)==1
 @test any(r->r["technique"]=="explore",rows)
 @test isempty(m["edges"]) # Selecting goals did not invent a route.
 m["acquisition"]["choice"]=LW.D("ref"=>7,"source"=>"memory")
 options=[LW.D("mb_chunk"=>"a"),LW.D("food_ref"=>8)]
 @test length(LW.food_goal_route_filter!(m,copy(options),"food"))==1
 @test LW.food_goal_route_filter!(m,copy(options),"home")==options
 m["acquisition"]["choice"]=LW.D("ref"=>nothing)
 @test isempty(LW.food_goal_route_filter!(m,copy(options),"food"))
 mixed=[LW.D("mb_chunk"=>"a"),LW.D("action"=>"walk"),LW.D("mb_control"=>"abandon")]
 @test length(LW.food_goal_navigation_filter!(m,copy(mixed),"food"))==2
 @test LW.food_goal_navigation_filter!(m,copy(mixed),"home")==mixed
 LW.mb_food_site_observe!(m,7,0,1,"visible_empty")
 m["acquisition"]["next_us"]=0
 LW.acquisition_targets!(m,Any[],loop,2)
 after=only(filter(r->r["ref"]==7,last(m["acquisition"]["records"])["candidates"]))
 before=only(filter(r->r["ref"]==7,rows))
 @test after["priority"]<before["priority"]
 @test after["food_availability"]==.25
 m["acquisition"]["choice"]=copy(after);m["acquisition"]["next_us"]=100
 recorded=length(m["acquisition"]["records"])
 @test isempty(LW.acquisition_targets!(m,Any[],loop,3))
 @test length(m["acquisition"]["records"])==recorded
 LW.mb_food_site_observe!(m,7,1,3,"visible")
 @test LW.mb_food_availability(m,c)==1.
 io=IOBuffer();serialize(io,m);seekstart(io)
 @test length(LW.food_goal_sources(deserialize(io),Any[]))==1
end
@testset "search terminates at selected food source" begin
 m=LW.mb_map_state("a";chunks=true)
 for name in ("start","near","far")
  m["nodes"][name]=LW.D("food"=>name!="start","home"=>name=="near")
 end
 for (key,to,cost) in (("n","near",0.),("f","far",3.))
  m["edges"][key]=LW.D("from"=>"start","to"=>to,"action"=>"walk","energy_sum"=>cost,"samples"=>1,"matches"=>1,"misses"=>0)
 end
 m["chunks"]["far"]=LW.D("goal"=>"food","to"=>"far","food_ref"=>7)
 m["acquisition"]=LW.acquisition_state();m["acquisition"]["choice"]=LW.D("ref"=>7)
 @test LW.mb_search(m,"start","food",0).solution.node=="far"
 @test LW.mb_search(m,"start","home",0).solution.node=="near"
 m["acquisition"]["choice"]=LW.D("ref"=>nothing)
 @test LW.mb_search(m,"start","food",0).solution===nothing
end
