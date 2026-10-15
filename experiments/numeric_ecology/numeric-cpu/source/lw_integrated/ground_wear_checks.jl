include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "World wear recovery and receipt boundary" begin
 g=GroundWear(100)
 @test wear_factor(g,(.2,.2))==1.
 tread!(g,"op","a",(.1,.1),(.6,.1),0)
 @test sum(c["distance"] for c in values(g.cells))≈.5
 tread!(g,"op","a",(.1,.1),(.6,.1),0)
 @test g.operations==1
 @test_throws ErrorException tread!(g,"different","a",(.1,.1),(.6,.1),0)
 tread!(g,"op-b","b",(.1,.1),(.6,.1),0)
 @test g.operations==2
 @test wear_factor(g,(.2,.2))≈.95
 advance_wear!(g,100)
 @test wear_factor(g,(.2,.2))≈.95
 advance_wear!(g,125)
 @test wear_factor(g,(.2,.2))≈.975
 @test_throws ErrorException tread!(g,"stale","a",(.1,.1),(.6,.1),0)
 @test_throws ErrorException advance_wear!(g,124)
 advance_wear!(g,150)
 @test wear_factor(g,(.2,.2))==1.
 @test wear_snapshot(g)["cells"]["0,0"]["distance"]≈1.
 @test length(g.receipts)==0
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--ground","patches","--ground-wear",mode,"--general-sleep","apply","--sleep-retention","strata"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String))
 validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "shared living ground" begin
   @test r.ground_wear.operations>0
   @test sum(c.distance for c in values(r.ground_wear.cells))≈sum(a.distance for a in values(r.final_agents))
   @test all(c.wear>=0 && c.wear<=c.distance+1e-9 for c in values(r.ground_wear.cells))
   @test all(s.delta_mismatches==0 for s in values(r.ground_effects))
  end
 end
end
