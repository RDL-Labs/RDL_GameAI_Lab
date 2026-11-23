using Test,JSON3,Serialization
include("../julia_migration/lw_integrated/native.jl")
@testset "food place residual and observed empty site" begin
 s=mb_map_state("a")
 obs=D("source"=>"ob:1000000:a","coverage"=>"complete","features"=>[D("color"=>"brown","azimuth"=>[-5.,5.],"range_band"=>"near","distance"=>1.)])
 mb_observe!(s,obs,1_000_000);key=s["current"].key
 move=D("visible"=>Any[],"food_coverage"=>"complete")
 receipt=D("now"=>0,"goal"=>"food","status"=>"performed","action"=>"scan","from"=>key,"offset"=>0.,"distance"=>0.)
 coarse=deepcopy(s)
 mb_search_resistance_observe!(s,move,obs,receipt,1_000_000;rho="fine")
 r=s["food_search_resistance"]
 @test r["effort"][key]==.5
 mb_search_resistance_observe!(coarse,move,obs,receipt,1_000_000;rho="coarse")
 @test coarse["food_search_resistance"]["effort"][key]==.125
 prior=deepcopy(r)
 mb_search_resistance_observe!(s,move,obs,receipt,1_000_000;rho="fine")
 @test r==prior
 for change in (D("goal"=>"home"),D("now"=>-1),D("status"=>"blocked"))
  mb_search_resistance_observe!(s,move,obs,merge(receipt,change),1_000_000)
  @test r==prior
 end
 mb_food_site_observe!(s,7,0,1_000_000,"harvest_contact")
 @test r["sites"][7]["H"]==1.
 mb_food_site_observe!(s,7,0,2_000_000,"visible_empty")
 @test r["sites"][7]["H"]==1.
 opts=[D("method"=>"site","action"=>"walk","priority"=>3.,"direction"=>2,"food_ref"=>7),D("method"=>"new","action"=>"walk","direction"=>4,"priority"=>3.)]
 home=deepcopy(opts);mb_search_resistance_project!(s,home,"home",move,1_000_000);@test home==opts
 mb_search_resistance_project!(s,opts,"food",move,1_000_000)
 @test opts[1]["priority"]<opts[2]["priority"]
 loop=BasicLoop("a:food";probabilistic=true)
 @test 0<method_distribution(loop,opts)[1]<.5
 io=IOBuffer();serialize(io,s);seekstart(io);@test deserialize(io)["food_search_resistance"]==r
 mb_food_site_observe!(s,7,1,3_000_000,"visible")
 @test r["sites"][7]["H"]==0
 mb_search_resistance_observe!(s,D("visible"=>[D("ref"=>7)]),obs,receipt,1_000_000)
 @test !haskey(r["effort"],key)
 @test isempty(s["edges"])
 unknown=mb_map_state("a");mb_observe!(unknown,obs,1_000_000)
 mb_search_resistance_observe!(unknown,D("visible"=>Any[]),obs,receipt,1_000_000)
 @test isempty(unknown["food_search_resistance"]["effort"])
end
@testset "legacy horizon pressure removed" begin
 s=horizon_state("a");s["H"]=32;s["count"]=7
 for i in 1:400;horizon_result!(s,"a","op$i","exploration","moved",false);end
 @test s["H"]==s["count"]==0
 @test isempty(s["events"])
 fan=D("source"=>"current","features"=>[D("range_band"=>"far","azimuth"=>[37.5,52.5])])
 move=D("energy"=>D("rows"=>[D("cost"=>1.) for _ in 1:5]))
 @test only(horizon_candidates(s,fan,move))["priority"]==2.
 s["H"]=32
 @test only(horizon_candidates(s,fan,move))["priority"]==2.
end
