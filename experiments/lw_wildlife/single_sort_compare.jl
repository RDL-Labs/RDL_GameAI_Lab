using JSON3
comparison_root=ARGS[1]
comparison_rows=Any[]
for day in (39,41)
    baseline_dir=joinpath(comparison_root,"single-sort-baseline$day-20261111")
    revised_dir=joinpath(comparison_root,"single-sort$day-20261111")
    baseline=JSON3.read(read(joinpath(baseline_dir,"result.json"),String),Dict{String,Any})
    revised=JSON3.read(read(joinpath(revised_dir,"result.json"),String),Dict{String,Any})
    matches=Dict(k=>baseline[k]==revised[k] for k in ("actions","physical","home_activity"))
    matches["events"]=JSON3.read(read(joinpath(baseline_dir,"day-events.json"),String),Vector{Any})==
        JSON3.read(read(joinpath(revised_dir,"day-events.json"),String),Vector{Any})
    matches["cognition_ticks"]=all(v==get(revised["timing"],k,nothing) for (k,v) in baseline["timing"] if occursin(':',k)) &&
        all(v==get(baseline["timing"],k,nothing) for (k,v) in revised["timing"] if occursin(':',k))
    @assert all(values(matches)) matches
    metrics=Dict(k=>Dict("before"=>baseline[k],"after"=>revised[k],"change_percent"=>100*(revised[k]/baseline[k]-1)) for k in ("call_seconds","allocated_bytes","gc_seconds"))
    for k in ("day_seconds","save_seconds","sleep_seconds")
        metrics[k]=Dict("before"=>baseline["timing"][k],"after"=>revised["timing"][k],"change_percent"=>100*(revised["timing"][k]/baseline["timing"][k]-1))
    end
    before=baseline["timing"]["day_seconds"]-baseline["timing"]["save_seconds"]
    after=revised["timing"]["day_seconds"]-revised["timing"]["save_seconds"]
    metrics["day_without_save_seconds"]=Dict("before"=>before,"after"=>after,"change_percent"=>100*(after/before-1))
    push!(comparison_rows,(;day,matches,metrics,baseline_dir,revised_dir))
end
result=(note="One measured replay per variant/day in this comparison; baseline rerun after revised days. Same frozen input/checkpoint, 512 tick warmup, CPU sampling and checkpoint save. Differences include measurement variation; not a repeated benchmark.",rows=comparison_rows)
write(ARGS[2],JSON3.write(result));println(JSON3.write(result))
