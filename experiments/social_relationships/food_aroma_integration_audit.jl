using JSON3, Test
out=ARGS[1]
isfile(joinpath(out,"completed.json")) || error("integration not complete")
result=JSON3.read(read(joinpath(out,"run/result.json"),String),Dict{String,Any})
rows=Dict{String,Any}()
for (actor,map) in result["mb_map"]
 sensory=get(map,"food_aroma",Dict())
 rows[actor]=Dict("emissions"=>get(map,"food_aroma_stats",Dict()),
 "observed_ticks"=>get(sensory,"observed_ticks",0),"recall_ticks"=>get(sensory,"recall_ticks",0),
 "learned_foods"=>count(m->haskey(m,"aroma_features"),values(get(map,"food_taste_experiences",Dict()))),
 "record_count"=>length(get(sensory,"records",[])))
end
@testset "LW aroma integrated evidence" begin
 @test length(result["daily"])==1
 @test sum(sum(values(r["emissions"]);init=0) for r in values(rows))>0
 @test sum(r["observed_ticks"] for r in values(rows))>0
 @test sum(r["recall_ticks"] for r in values(rows))>0
 @test all(r["record_count"]<=64 for r in values(rows))
end
completion=JSON3.read(read(joinpath(out,"completed.json"),String),Dict{String,Any})
report=Dict("days"=>1,"seconds"=>completion["seconds"],"bytes"=>completion["bytes"],"gctime"=>completion["gctime"],"actors"=>rows)
write(joinpath(out,"aroma_audit.json"),JSON3.write(report));println(JSON3.write(report))
