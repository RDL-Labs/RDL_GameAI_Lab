include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
out=ARGS[1];seed=ARGS[2]
args=[joinpath(out,"first"),"--days","30","--seed",seed,"--food","renewable",
 "--hazards","mixed","--safety-methods","continuous","--food-body","on",
 "--social-response","experience","--general-sleep","apply","--sleep-retention","strata",
 "--sleep-maintenance","on","--ground","patches","--ground-wear","on",
 "--ground-perception","on","--ground-continuity","on","--running","on",
 "--climbing","on","--low-obstacles","on","--dropping","on"]
native_main(args)
input=JSON3.read(read(joinpath(out,"first","spec.json"),String))
r=JSON3.read(read(joinpath(out,"first","result.json"),String))
validate_integrated(r,input)
@testset "thirty-day integrated bounds" begin
 @test length(r.daily)==30 && length(r.day_starts)==30
 @test all(length(s.records)<=192 for s in values(r.sleep_action_models))
 @test all(length(s.models)<=8 for s in values(r.ground_continuity))
 @test all(s.return_purpose.completed<=s.return_purpose.entries for s in values(r.final_agents))
 @test all(length(s.events)<=32 for s in values(r.safety_methods))
end
# Exact replay is a reproducibility gate within Julia, not Python parity.
native_main([joinpath(out,"replay"),"--spec",joinpath(out,"first","spec.json")])
@testset "frozen native replay" begin
 @test read(joinpath(out,"first","result.json"))==read(joinpath(out,"replay","result.json"))
end
