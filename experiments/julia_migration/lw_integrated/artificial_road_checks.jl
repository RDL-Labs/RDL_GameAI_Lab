include(joinpath(@__DIR__,"native.jl"))
using Test
roads(days=3650) = JSON3.read(JSON3.write([(cells=[[0,z] for z in 0:5],lifetime_days=days)]))
@testset "artificial surface lifetime and history" begin
 g=GroundWear(100);place_roads!(g,roads())
 @test isempty(g.cells) && g.operations==0
 @test wear_factor(g,(.2,.2))==.5
 @test wear_factor(g,(-.2,.2))==1.
 advance_wear!(g,30*100)
 @test wear_factor(g,(.2,.2))≈.5+.5*30/3650
 advance_wear!(g,1825*100)
 @test wear_factor(g,(.2,.2))==.75
 restored=restore_wear(JSON3.read(JSON3.write(wear_snapshot(g))),100)
 @test wear_snapshot(restored)==wear_snapshot(g)
 for state in (g,restored)
  advance_wear!(state,3650*100)
  @test wear_factor(state,(.2,.2))==1.
 end
 @test isempty(g.cells)
 # Ordinary traffic is not construction repair, but survives expired pavement.
 tread!(g,"walk","a",(.1,.1),(.6,.1),g.now)
 @test g.roads[(0,0)]["built_us"]==0
 @test wear_factor(g,(.2,.2))≈.975
 advance_wear!(g,g.now+200)
 @test wear_factor(g,(.2,.2))==1.
 old=wear_snapshot(GroundWear(100));delete!(old,"artificial_roads");delete!(old,"artificial_road_rule")
 @test isempty(restore_wear(JSON3.read(JSON3.write(old)),100).roads)
 for days in (0,-1)
  @test_throws ErrorException place_roads!(GroundWear(100),roads(days))
 end
 @test_throws ErrorException place_roads!(GroundWear(100),JSON3.read("[{\"cells\":[[0.5,0]]}]"))
 frozen=GroundWear(100;recovery=false);place_roads!(frozen,roads())
 advance_wear!(frozen,4000*100)
 @test wear_factor(frozen,(.2,.2))==.5
end
@testset "local road perception and movement" begin
 g=GroundWear(100);place_roads!(g,roads())
 w=(positions=Dict("a"=>(.2,.2)),obstacles=RDLMigrationProbe.Circle[])
 view=ground_appearance(w,"a",Dict("a"=>0.),g,0)
 @test all(view["cells"][i]["appearance"]=="bare_ground" for i in 7:9)
 memory=ground_memory("a");update_ground!(memory,view,nothing)
 move=D("energy"=>D("rows"=>[D("cost"=>1.) for _ in 1:5]))
 @test !isempty(ground_proposals(memory,move))
 @test !haskey(view,"artificial_roads")
 water=ground_appearance(w,"a",Dict("a"=>0.),g,0;dry=p->false)
 @test all(c["appearance"]=="water" for c in water["cells"])
 push!(w.obstacles,RDLMigrationProbe.Circle(.2,2.2,.5))
 hidden=ground_appearance(w,"a",Dict("a"=>0.),g,0)
 @test hidden["cells"][8]["appearance"]===nothing
end
if !isempty(ARGS)
 out=abspath(ARGS[1]);mkpath(out)
 input=JSON3.read(read(joinpath(@__DIR__,"search_review_spec.json"),String),Dict{String,Any})
 input["config"]["days"]=1
 # A two-cell-wide example leading south from home through the gate location.
 input["scene"]["artificial_roads"]=[D("cells"=>[[x,z] for x in -1:0 for z in -12:5],"lifetime_days"=>3650)]
 path=joinpath(out,"input.json");write(path,JSON3.write(input))
 native_main([joinpath(out,"run"),"--spec",path])
 r=JSON3.read(read(joinpath(out,"run/result.json"),String))
 @testset "integrated road placement" begin
  @test length(r.daily)==1
  @test length(r.ground_wear.artificial_roads)==36
  @test all(v.built_us==0 for v in values(r.ground_wear.artificial_roads))
  @test all(0<=v.wear<=v.distance+1e-8 for v in values(r.ground_wear.cells))
  @test all(all(isfinite,p.position) for p in values(r.daily[1].physical))
 end
end
