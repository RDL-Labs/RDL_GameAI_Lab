using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
input=JSON3.read(read(ARGS[1],String),Dict{String,Any})
input["scene"]["configured_camp_landmark"]=true
input["scene"]["configured_camp_experience"]=true
input["config"]["days"]=2
input["clock"]["day_us"]=600_000_000
input["clock"]["phase_boundaries_us"]=[1_000_000,400_000_000,500_000_000,600_000_000]
input["clock"]["quiet_night_us"]=550_000_000
input["clock"]["sleep_rest_us"]=50_000_000
r,_=run_integrated(JSON3.read(JSON3.write(input)))
@testset "observed camp episode and one completion reward" begin
    for a in IDS
        p=r["mb_map"][a]["place_mb"];l=r["home_observation"][a]["camp_landmark"]
        @test l["tour_completed"] && l["stage"]==6
        @test p["complete"] && p["reward_count"]==1 && p["initial_reward"]==20.
        @test p["rest_ticks"]==60
        @test length(p["members"])>=2 && !isempty(p["links"])
        @test all(haskey(p["members"],e["from"]) && haskey(p["members"],e["to"]) for e in values(p["links"]))
        @test l["selected"]==0 # The old permanent fixed bonus is disabled.
        println(a," ",JSON3.write(D("complete"=>p["complete"],"members"=>length(p["members"]),"links"=>length(p["links"]),"selected"=>p["selected"],"memory_selected"=>p["memory_selected"],"reward"=>p["initial_reward"])))
    end
end
@testset "no reward farming or unobserved recall" begin
    p=deepcopy(r["mb_map"][first(IDS)]["place_mb"])
    loop=BasicLoop("home";probabilistic=true,seed=1)
    @test !mb_place_finish!(p,loop,p["signature"],999999999)
    @test isempty(loop.methods)
    fresh=mb_place_state()
    @test !mb_place_finish!(fresh,loop,"test",0)
    move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
    @test mb_place_candidate!(fresh,move)===nothing
    p["active"]=false;mb_place_recall!(p,nothing,nothing,false)
    @test !p["active"]
    view=D("signature"=>p["signature"],"forward"=>5.,"right"=>0.)
    mb_place_recall!(p,view,nothing,false)
    @test p["active"]
    mb_place_recall!(p,nothing,D("operation"=>"test","forward"=>1.,"right"=>0.,"yaw"=>90.),false)
    @test p["estimate"]["right"]≈-4
    @test p["active"] && !p["visible"]
    c=mb_place_candidate!(p,move)
    @test c!==nothing && !haskey(c,"observation_log_prior") && c["mb_place_memory"]
    mb_place_recall!(p,nothing,nothing,true)
    @test !p["active"]
end
write("outputs/camp-experience-short-result.json",JSON3.write(r))

@testset "uncertain recall scans instead of stopping" begin
    p=mb_place_state();p["complete"]=true;p["active"]=true;p["estimate"]["uncertainty"]=4.
    c=mb_place_candidate!(p,D())
    @test c["action"]=="scan" && c["scan_angle"]==60.
end
