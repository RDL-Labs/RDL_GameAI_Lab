using JSON3
baseline=JSON3.read(read(joinpath(ARGS[1],"result.json"),String),Dict{String,Any})
trial=JSON3.read(read(joinpath(ARGS[2],"result.json"),String),Dict{String,Any})
function timing_summary(result)
    timing=result["timing"]
    animal=sum(timing[k] for k in ("animal_prepare_seconds","animal_advance_seconds","animal_motion_seconds"))
    total=timing["total_tick_and_daily_seconds"]
    (total_seconds=total,save_seconds=timing["checkpoint_seconds"],animal_seconds=animal,
     human_and_common_seconds=total-timing["checkpoint_seconds"]-timing["daily_before_save_seconds"]-animal,
     fine_calls=timing["rho_fine_calls"],coarse_calls=timing["rho_coarse_calls"],
     allocated_bytes_including_restore=result["allocated_bytes"])
end
actors=Dict{String,Any}()
for actor in sort(collect(keys(trial["daily_action_counts"])))
    trial_counts=trial["daily_action_counts"][actor]
    baseline_counts=Dict(k=>get(trial_counts,k,0)+get(baseline["actual"]["counts"][actor],k,0)-get(trial["actual"]["counts"][actor],k,0)
        for k in union(keys(baseline["actual"]["counts"][actor]),keys(trial["actual"]["counts"][actor])))
    @assert sum(values(baseline_counts))==sum(values(trial_counts))==17280
    summaries=Dict{String,Any}()
    for (name,result,counts) in (("baseline",baseline,baseline_counts),("boxes",trial,trial_counts))
        physical=result["actual"]["physical"][actor]
        summaries[name]=(actions=Dict(k=>v for (k,v) in counts if v!=0),body=physical["body"],
            position=physical["position"],inventory=physical["inventory"],stock=physical["personal_stock"],
            return_completed_total=physical["return_purpose"]["completed"],return_active=physical["return_purpose"]["active"])
    end
    actors[actor]=summaries
end
comparison=(day=trial["day"],baseline=timing_summary(baseline),boxes=timing_summary(trial),
    baseline_matches_original=baseline["matched"],actors)
write(ARGS[3],JSON3.write(comparison));println(JSON3.write(comparison))
