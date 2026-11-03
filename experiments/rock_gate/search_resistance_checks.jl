using Test,JSON3
include("../julia_migration/lw_integrated/native.jl")
@testset "food search resistance is observation and purpose scoped" begin
 s=mb_map_state("a");s["food_search_resistance_enabled"]=true
 obs=D("source"=>"ob:1000000:a","coverage"=>"complete","features"=>[D("color"=>"brown","azimuth"=>[-5.,5.],"range_band"=>"near","distance"=>1.)])
 mb_observe!(s,obs,1_000_000);key=s["current"].key
 move=D("visible"=>Any[],"food_coverage"=>"complete")
 receipt=D("now"=>0,"goal"=>"food","status"=>"performed","action"=>"scan","from"=>key,"offset"=>0.,"distance"=>0.)
 mb_search_resistance_observe!(s,move,obs,receipt,1_000_000;rho="fine")
 r=s["food_search_resistance"];@test r["effort"][key]==1.
 coarse=deepcopy(s);mb_search_resistance_observe!(coarse,move,obs,receipt,1_000_000;rho="coarse")
 @test coarse["food_search_resistance"]["effort"][key]==1.25
 mb_search_resistance_observe!(s,move,obs,merge(receipt,D("action"=>"walk","distance"=>.5)),1_000_000;rho="fine")
 @test r["effort"][key]≈1.02
 before=deepcopy(r)
 mb_search_resistance_observe!(s,move,obs,merge(receipt,D("goal"=>"home")),1_000_000;rho="fine")
 mb_search_resistance_observe!(s,move,obs,merge(receipt,D("now"=>-1)),1_000_000;rho="fine")
 mb_search_resistance_observe!(s,move,obs,merge(receipt,D("status"=>"blocked")),1_000_000;rho="fine")
 @test r==before
 opts=[D("method"=>"known","action"=>"walk","priority"=>3.,"mb_expected"=>key),D("method"=>"novel","action"=>"walk","direction"=>4,"priority"=>3.)]
 home=deepcopy(opts);mb_search_resistance_project!(s,home,"home",move,1_000_000);@test home==opts
 mb_search_resistance_project!(s,opts,"food",move,1_000_000)
 @test opts[1]["priority"]<opts[2]["priority"]==3.
 @test opts[1]["mb_search_resistance"]["penalty"]≈log1p(1.02)
 mb_search_resistance_selected!(s,opts[1],1_000_000);@test r["selected"]==1
 mb_search_resistance_observe!(s,D("visible"=>[D("ref"=>0)]),obs,receipt,1_000_000;rho="fine")
 @test !haskey(r["effort"],key) && r["released"]==1
 off=mb_map_state("a");mb_search_resistance_observe!(off,move,obs,receipt,1_000_000)
 @test !haskey(off,"food_search_resistance")
 original=deepcopy(opts);@test mb_search_resistance_project!(off,opts,"food",move,1_000_000)==original
 @test isempty(s["edges"]) # Negative evidence never edits transition geometry.
end
