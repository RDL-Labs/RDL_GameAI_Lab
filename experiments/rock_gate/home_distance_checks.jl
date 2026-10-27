using Test
const D=Dict{String,Any}
include("../../src/lw/perception/home_distance.jl")
@testset "observed home and egocentric distance" begin
    s=home_distance_state()
    @test home_distance_profile!(s,nothing)=="coarse"
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
    @test home_distance_profile!(s,nothing)=="coarse"
    observe_home_distance!(s,D("forward"=>1.,"right"=>0.))
    @test home_distance_profile!(s,nothing)=="fine"
end
