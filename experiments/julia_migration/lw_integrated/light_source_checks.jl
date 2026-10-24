include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "emissive property and observed light" begin
 lamp=(x=0.,z=90.,radius=.1,height=2.,color="orange",light_source=1.)
 @test isempty(light_fan([lamp],(0.,0.),0.))
 @test length(light_fan([lamp],(0.,0.),0.;night=true))==1
 night=landmark_fan([lamp],(0.,0.),0.,"n";night=true)
 @test isempty(night["features"]) && length(night["lights"])==1
 @test !haskey(only(night["lights"]),"distance") && !haskey(only(night["lights"]),"ref")
 wall=(x=0.,z=45.,radius=2.,height=3.,color="gray")
 @test isempty(light_fan([lamp,wall],(0.,0.),0.;night=true))
 @test isempty(light_fan([lamp],(0.,0.),180.;night=true))
 @test isempty(light_fan([merge(lamp,(light_source=0.,))],(0.,0.),0.;night=true))
 @test !isempty(light_fan([merge(lamp,(light_source=4.,))],(0.,0.),0.))
 @test_throws Exception light_fan([merge(lamp,(light_source=-1.,))],(0.,0.),0.)
 move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
 c=only(landmark_candidates(move,night,route_memory(),"home","n"))
 @test c["method"]=="light:0" && c["route"]===nothing && c["landmark_color"]===nothing
 close=landmark_fan([merge(lamp,(z=1.5,))],(0.,0.),0.,"close";night=true)
 @test !any(startswith(c["method"],"light:") for c in landmark_candidates(move,close,route_memory(),"food","close"))
 @test prepare_landmark_objects([lamp])[1].light_source==1.
 @test prepare_landmark_objects([wall])[1].light_source==0.
end
