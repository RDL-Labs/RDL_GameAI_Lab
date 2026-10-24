include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "near torch-like landmark is actionable" begin
 post=(x=0.,z=4.,radius=.3,height=2.,color="orange")
 view=landmark_fan([post],(0.,0.),0.,"ob")
 move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
 cs=landmark_candidates(move,view,route_memory(),"food","ob")
 @test !isempty(view["features"]) && all(f["range_band"]=="near" for f in view["features"])
 @test only(cs)["method"]=="landmark:orange"
 @test only(cs)["steering_angle"]≈0
 @test only(cs)["route"]===nothing
 @test only(landmark_patches(view,"orange"))["distance"]≈3.7
 close=landmark_fan([post],(0.,2.),0.,"near")
 @test isempty(landmark_candidates(move,close,route_memory(),"food","near"))
 hidden=landmark_fan([post,(x=0.,z=2.,radius=1.,height=3.,color="gray")],(0.,0.),0.,"hidden")
 @test !any(c["method"]=="landmark:orange" for c in landmark_candidates(move,hidden,route_memory(),"food","hidden"))
 behind=landmark_fan([post],(0.,0.),180.,"behind")
 @test isempty(landmark_candidates(move,behind,route_memory(),"food","behind"))
 blocked=deepcopy(move);foreach(r->r["cost"]=nothing,blocked["energy"]["rows"])
 @test isempty(landmark_candidates(blocked,view,route_memory(),"food","ob"))
 @test isempty(landmark_candidates(move,merge(view,D("coverage"=>"partial")),route_memory(),"food","ob"))
end
