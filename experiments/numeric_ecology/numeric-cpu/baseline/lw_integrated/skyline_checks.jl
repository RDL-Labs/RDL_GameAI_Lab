include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "finite elevated observation and home relation" begin
 objects=[(x=0.,z=5.,radius=.5,height=2.,color="green"),(x=0.,z=20.,radius=1.,height=20.,color="ochre")]
 view=skyline_fan(objects,(0.,0.),0.,"ob:0:a")
 @test length(view["features"])<=39
 @test any(f->f["elevation"]==0 && f["color"]=="green",view["features"])
 @test any(f->f["elevation"]==15 && f["color"]=="ochre",view["features"])
 @test all(!haskey(f,"x") && !haskey(f,"distance") for f in view["features"])
 behind=skyline_fan(objects,(0.,0.),180.,"ob:1:a")
 @test isempty(behind["features"])
 thin=[(x=20sind(5.),z=20cosd(5.),radius=.1,height=20.,color="gray")]
 @test isempty(skyline_fan(thin,(0.,0.),0.,"ob:2:a")["features"])
 @test !isempty(skyline_fan(thin,(0.,0.),0.,"ob:2:a";subrays=true)["features"])
 s=skyline_state();near=skyline_fan([(x=0.,z=4.,radius=1.,height=12.,color="ochre")],(0.,0.),0.,"ob:0:a")
 record_skyline!(s,near)
 @test s["home_memory"]["color"]=="ochre"
 @test s["home_memory"]["source"]=="ob:0:a"
 w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[],bodies=Dict("a"=>Body(10.,0.,90.,0.)),inventory=Dict("a"=>0))
 moves=movement_observation(w,"a",Dict("a"=>0.),Any[],Int[])
 cs=skyline_home_candidates(s,view,moves)
 @test only(cs)["direction"]==2
 @test only(cs)["question"]=="movement_progress"
 @test isempty(skyline_home_candidates(s,behind,moves))
 @test isempty(skyline_home_candidates(s,merge(view,D("coverage"=>"partial")),moves))
 exhausted=deepcopy(moves);for r in exhausted["energy"]["rows"];r["cost"]=nothing;end
 @test isempty(skyline_home_candidates(s,view,exhausted))
 @test home_observation(w,"a",Dict("a"=>0.),[0.,10.];range=6)===nothing
 @test home_observation(w,"a",Dict("a"=>0.),[0.,5.];range=6)!==nothing
 for i in 1:20;record_skyline!(s,behind);end
 @test length(s["records"])==16 && s["home_memory"]["color"]=="ochre"
 emptyfirst=skyline_state();record_skyline!(emptyfirst,behind);record_skyline!(emptyfirst,near)
 @test emptyfirst["home_memory"]===nothing
end
root=ARGS[1]
for mode in ("off","rays","subrays")
 native_main([joinpath(root,mode),"--days","3","--seed","20261005","--food","renewable","--skyline",mode])
 r=JSON3.read(read(joinpath(root,mode,"result.json"),String));input=JSON3.read(read(joinpath(root,mode,"spec.json"),String))
 validate_integrated(r,input)
 if mode!="off"
  @test all(s.observations==3*17280 for s in values(r.skyline))
  @test all(length(s.records)==16 for s in values(r.skyline))
  @test all(s.home_memory!==nothing for s in values(r.skyline))
 end
end
native_main([joinpath(root,"replay"),"--spec",joinpath(root,"subrays","spec.json")])
@test read(joinpath(root,"subrays","result.json"))==read(joinpath(root,"replay","result.json"))
