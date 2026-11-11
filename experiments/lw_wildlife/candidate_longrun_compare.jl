using JSON3, Serialization
root=abspath(ARGS[1]);days=parse(Int,ARGS[2])
include(joinpath(root,"baseline/source/src/lw/LW.jl"))
# Use the same recursive value/RNG comparison as the representative-day check.
comparison_source=read(joinpath(root,"state_compare.jl"),String)
comparison_source="function state_equal"*first(split(last(split(comparison_source,"function state_equal")),"baseline_dir="))
Base.include_string(Main,comparison_source)
daily=Any[]
for day in 1:days
    before=JSON3.read(read(joinpath(root,"baseline/run/day-$day.json"),String),Dict{String,Any})
    after=JSON3.read(read(joinpath(root,"optimized/run/day-$day.json"),String),Dict{String,Any})
    push!(daily,(;day,humans_equal=before["humans"]==after["humans"],home_activity_equal=before["home_activity"]==after["home_activity"],
        baseline_seconds=before["total_seconds"],optimized_seconds=after["total_seconds"],
        baseline_without_save=before["simulation_seconds"],optimized_without_save=after["simulation_seconds"]))
end
file="day-"*lpad(days,3,'0')*".jls"
before_state=deserialize(joinpath(root,"baseline/run/checkpoints",file)).state
after_state=deserialize(joinpath(root,"optimized/run/checkpoints",file)).state
checks=Dict(string(key)=>state_equal(before_state[key],after_state[key]) for key in (:events,:counts,:mb_maps,:loops,:states,:storage_stats))
checks["daily_humans"]=all(x.humans_equal for x in daily)
checks["daily_home_activity"]=all(x.home_activity_equal for x in daily)
baseline=JSON3.read(read(joinpath(root,"baseline/run/completed.json"),String),Dict{String,Any})
optimized=JSON3.read(read(joinpath(root,"optimized/run/completed.json"),String),Dict{String,Any})
write(joinpath(root,"comparison.json"),JSON3.write((;days,checks,baseline,optimized,daily)))
@assert all(values(checks)) checks
println(JSON3.write((;checks,baseline_seconds=baseline["total_seconds"],optimized_seconds=optimized["total_seconds"])))
