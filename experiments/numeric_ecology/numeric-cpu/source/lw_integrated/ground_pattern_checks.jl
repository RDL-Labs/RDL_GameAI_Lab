include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "Python sampled grouping reference" begin
 for row in JSON3.read(read(joinpath(@__DIR__,"ground_pattern_reference.json"),String))
  cells=[D(string(k)=>v for (k,v) in pairs(c)) for c in row.cells]
  v=D("source"=>D("actor"=>"a","observation"=>"o","capture_us"=>0),"cells"=>cells,"coverage"=>row.coverage)
  actual=ground_patterns(v)
  for g in actual["groups"];delete!(g,"pattern_ref");end
  @test JSON3.read(JSON3.write(actual["groups"]))==row.groups
 end
 g=GroundWear(100);w=(positions=Dict("a"=>(0.,0.)),obstacles=[RDLMigrationProbe.Circle(0.,2.,.5)])
 v=ground_appearance(w,"a",Dict("a"=>0.),g,0)
 @test length(v["cells"])==15
 @test v["coverage"]=="partial"
 @test v["cells"][8]["appearance"]===nothing
 @test !haskey(v["source"],"position")
 once=GroundWear(100);often=GroundWear(100)
 for state in (once,often);tread!(state,"op","a",(.1,.1),(.6,.1),0);end
 for t in 101:120;advance_wear!(often,t);wear_factor(often,(.2,.2));end
 advance_wear!(once,120)
 @test wear_snapshot(once)==wear_snapshot(often)
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--ground","patches","--ground-wear","on","--ground-perception",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String))
 validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
end
@testset "descriptive observation is action neutral" begin
 off=JSON3.read(read(joinpath(out,"off","result.json"),String),D)
 on=JSON3.read(read(joinpath(out,"on","result.json"),String),D)
 @test all(s["observations"]==51840 for s in values(on["ground_perception"]))
 @test all(length(s["records"])==16 for s in values(on["ground_perception"]))
 delete!(off,"ground_perception");delete!(on,"ground_perception")
 @test off==on
end
