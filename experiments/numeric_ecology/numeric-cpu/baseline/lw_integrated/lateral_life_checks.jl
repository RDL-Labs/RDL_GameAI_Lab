include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
out=ARGS[1];input=JSON3.read(read(ARGS[2],String),Dict{String,Any})
input["config"]["days"]=1;input["config"]["lateral_side"]="right"
input["config"]["goal_switch_threshold"]=3
mkpath(out);specfile=joinpath(out,"input.json");write(specfile,JSON3.write(input))
native_main([joinpath(out,"first"),"--spec",specfile])
spec=JSON3.read(read(specfile,String));r=JSON3.read(read(joinpath(out,"first","result.json"),String))
validate_integrated(r,spec)
@testset "right handed composed life" begin
 @test all(s.evaluations>0 for s in values(r.lateral))
 @test all(length(s.records)<=32 for s in values(r.lateral))
 @test all(t.side=="right" for s in values(r.lateral) for t in s.records)
 @test all(n.threshold==3 for a in values(r.day_starts[1]) for n in values(a.loops))
 @test all(a.return_purpose.completed<=a.return_purpose.entries for a in values(r.final_agents))
end
native_main([joinpath(out,"replay"),"--spec",specfile])
@test read(joinpath(out,"first","result.json"))==read(joinpath(out,"replay","result.json"))
