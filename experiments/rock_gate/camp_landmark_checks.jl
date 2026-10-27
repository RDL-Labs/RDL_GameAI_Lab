using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
input=JSON3.read(read(ARGS[1],String),Dict{String,Any})
scene=JSON3.read(JSON3.write(input["scene"]))
objects=prepare_landmark_objects(vcat(collect(scene.obstacles),collect(scene.visual_landmarks)))
@testset "configured camp landmark visibility and association" begin
    v=configured_camp_landmark_view(objects,(-.16,11.54),-177.57)
    @test v!==nothing
    @test configured_camp_landmark_view(objects,(-.16,11.54),-87.57)===nothing
    @test configured_camp_landmark_view(prepare_landmark_objects(scene.obstacles),(0.,11.5),180.)===nothing
    s=configured_camp_landmark_state()
    move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
    @test configured_camp_landmark_candidate!(s,v,move)===nothing
    configured_camp_landmark_observe!(s,v,nothing,true,0)
    @test !s["learned"]
    configured_camp_landmark_observe!(s,v,v,false,0)
    @test !s["learned"]
    configured_camp_landmark_observe!(s,v,v,true,0)
    @test s["learned"] && s["paired_home"]==1
    @test configured_camp_landmark_candidate!(s,nothing,move)===nothing
    c=configured_camp_landmark_candidate!(s,v,move)
    @test c["observation_log_prior"]==log(8.)
    @test !haskey(c,"target")
    blocked=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>nothing) for i in 0:4]))
    @test configured_camp_landmark_candidate!(s,v,blocked)===nothing
end
input["scene"]["configured_camp_landmark"]=true
input["config"]["days"]=2
input["clock"]["day_us"]=600_000_000
input["clock"]["phase_boundaries_us"]=[1_000_000,400_000_000,500_000_000,600_000_000]
input["clock"]["quiet_night_us"]=550_000_000
input["clock"]["sleep_rest_us"]=50_000_000
r,_=run_integrated(JSON3.read(JSON3.write(input)))
@testset "first day landmark checklist integration" begin
    for a in IDS
        s=r["home_observation"][a]["camp_landmark"]
        @test s["learned"]
        @test s["inside_checked"] && s["outside_checked"] && s["tour_completed"]
        println(a," ",JSON3.write(s))
    end
end
