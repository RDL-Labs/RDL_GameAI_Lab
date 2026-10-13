include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
out=ARGS[1];seed=ARGS[2];days=parse(Int,get(ENV,"LW_DAYS","30"))
@test days in (3,30)
args=[joinpath(out,"first"),"--days",string(days),"--seed",seed,"--food","renewable",
 "--hazards","mixed","--safety-methods","continuous","--food-body","on",
 "--social-response","experience","--general-sleep","apply","--sleep-retention","strata",
 "--sleep-maintenance","on","--ground","patches","--ground-wear","on",
 "--ground-perception","on","--ground-continuity","on","--running","on",
 "--climbing","on","--low-obstacles","on","--dropping","on","--layout","riparian","--stores","shared",
 "--regrowth-days","3","--regrowth-capacity","12","--skyline","subrays",
 "--reposition","on","--orientation","on","--relation-field","on",
 "--body-field","on","--movement-inertia","on","--exploration-horizon","on",
 "--experience-bundles","on","--bundle-credit","on","--selection-trails","on"]
native_main(args)
input=JSON3.read(read(joinpath(out,"first","spec.json"),String))
r=JSON3.read(read(joinpath(out,"first","result.json"),String))
validate_integrated(r,input)
@testset "latest integrated campaign bounds" begin
 @test length(r.daily)==days && length(r.day_starts)==days
 @test all(r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical)) for d in r.daily)
 @test all(a.personal_stock==0 for a in values(r.final_agents))
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
