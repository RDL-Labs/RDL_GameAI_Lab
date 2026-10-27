using Test
const D=Dict{String,Any}
include("../../src/lw/perception/home_distance.jl")
@testset "observed home and egocentric distance" begin
    s=home_distance_state()
    @test home_distance_profile!(s,nothing)=="fine"
    observe_home_distance!(s,D("forward"=>-2.,"right"=>0.))
    r=D("operation"=>"1","forward"=>3.,"right"=>0.,"yaw"=>90.)
    @test home_distance_profile!(s,r)=="fine"
    @test s["forward"]≈0 atol=1e-10
    @test s["right"]≈5
    u=s["uncertainty"];home_distance_profile!(s,r)
    @test s["uncertainty"]==u
    observe_home_distance!(s,nothing)
    @test s["right"]≈5
    s["right"]=11.;@test home_distance_profile!(s,nothing)=="fine"
    s["right"]=13.;@test home_distance_profile!(s,nothing)=="coarse"
    s["right"]=1.;s["uncertainty"]=4.
    @test home_distance_profile!(s,nothing)=="fine"
    observe_home_distance!(s,D("forward"=>1.,"right"=>0.))
    @test home_distance_profile!(s,nothing)=="fine"
end

@testset "bounded uncertainty confirmation" begin
    s=home_distance_state();observe_home_distance!(s,D("forward"=>30.,"right"=>0.))
    s["uncertainty"]=4.
    for _ in 1:24;@test home_distance_profile!(s,nothing)=="fine";end
    @test length(home_distance_candidates(s))==1
    @test home_distance_profile!(s,nothing)=="coarse"
    @test isempty(home_distance_candidates(s))
    @test s["uncertainty"]==4.
    @test s["unresolved"]==1
    for _ in 1:120;home_distance_profile!(s,nothing);end
    @test s["checking"]
    @test home_distance_candidates(s)[1]["scan_angle"]==-60.
    observe_home_distance!(s,nothing);@test s["uncertainty"]==4.
    observe_home_distance!(s,D("forward"=>5.,"right"=>1.))
    @test s["confirmed"]==1 && !s["checking"]
    @test s["uncertainty"]==.25
    @test home_distance_profile!(s,nothing)=="fine"
    s["uncertainty"]=100.;s["cooldown"]=100
    @test home_distance_profile!(s,nothing)=="fine"
    @test s["reason"]=="near"
    s["forward"]=13.;@test home_distance_profile!(s,nothing)=="coarse"
end
@testset "wrapped yaw receipt" begin
    s=home_distance_state();observe_home_distance!(s,D("forward"=>5.,"right"=>0.))
    home_distance_profile!(s,D("operation"=>"wrap","forward"=>0.,"right"=>0.,"yaw"=>-358.))
    @test s["uncertainty"]≈.2511
    @test s["right"]≈-5sind(2.)
end
