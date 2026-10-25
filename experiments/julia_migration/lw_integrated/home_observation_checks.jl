include("native.jl")
using Test
@testset "configured observation actions" begin
 s=configured_observation_state((0.,4.));clock=(quiet_night_us=14_400_000_000,)
 p=configured_observation_plan(s,(0.,4.),0.,30,30_000_000,clock,90.,0.)
 @test p["action"]=="scan" && p["scan_angle"]==30
 @test configured_observation_plan(s,(0.,4.),0.,0,0,clock,90.,.9)["action"]=="rest"
 @test configured_observation_plan(s,(0.,4.),0.,0,14_400_000_000,clock,90.,0.)["action"]=="rest"
 p=configured_observation_plan(s,(0.,4.),0.,240,240_000_000,clock,90.,0.)
 @test p["action"]=="walk" && p["approach_span"]<=.25
 @test p["configured_observation"] && !haskey(p,"mb_edge")
 @test configured_observation_food(D("visible"=>[D("distance"=>0.,"ref"=>3)]),true,0)["food_ref"]==3
 @test configured_observation_food(D("visible"=>[D("distance"=>2.,"ref"=>3)]),true,0)===nothing
 stock=[0,0];food=[(stock=4,renewable=false),(stock=4,)]
 @test replenish_food!(stock,food;capacity=12)==12 && stock==[0,12]
end
@testset "one day boundary and normal exploration resumes" begin
 input=JSON3.read(read(joinpath(@__DIR__,"search_review_spec.json"),String),Dict{String,Any})
 input["config"]["days"]=2;input["config"]["home_observation"]="on"
 input["config"]["mb_simulation"]="on";input["config"]["general_landmarks"]="on"
 input["config"]["body_purpose"]="on"
 for p in input["scene"]["positions"]
     push!(input["scene"]["food"],D("x"=>p[1],"z"=>p[2],"stock"=>4,"renewable"=>false))
 end
 input["clock"]["day_us"]=600_000_000;input["clock"]["phase_boundaries_us"]=[1_000_000,200_000_000,300_000_000,600_000_000]
 input["clock"]["quiet_night_us"]=400_000_000
 r,_=run_integrated(JSON3.read(JSON3.write(input)))
 @test all(s["completed"] && s["ticks"]==600 for s in values(r["home_observation"]))
 configured=[e for e in r["events"] if get(e,"method",nothing)=="configured_observation"]
 @test !isempty(configured) && all(e["us"]<600_000_000 for e in configured)
 @test any(e["us"]>=600_000_000 && e["action"]=="walk" for e in r["events"])
 @test all(s["map_at_end"]!==nothing for s in values(r["home_observation"]))
 @test any(e["us"]<600_000_000 && e["action"]=="pickup" && e["status"]=="picked_up" for e in r["events"])
 @test r["daily"][1]["physical"]["npc_a"]["body"]["reserve"]>30
end
