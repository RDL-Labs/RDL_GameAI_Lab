using JSON3,Serialization,Random
const root=abspath(ARGS[1]);const out=abspath(ARGS[2]);const day=parse(Int,ARGS[3]);const mode=ARGS[4]
ispath(out) && error("fresh output required");mkpath(out)
include(joinpath(root,"source/src/lw/LW.jl"))
Base.include(LW,joinpath(@__DIR__,"../../src/lw/observation/home_activity.jl"))
const actual=Ref{Any}()
struct ObserverFinished <: Exception end
function finish!(state)
    actual[]=state
    throw(ObserverFinished())
end
source=replace(read(joinpath(@__DIR__,"../../src/lw/simulation/day.jl"),String),r"(?m)^include.*\r?\n"=>"")
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
@assert count(anchor,source)==1
source=replace(source,anchor=>"Main.finish!(@lw_capture())")
write(joinpath(out,"instrumented_day.jl"),source)
Base.include_string(LW,source,joinpath(root,"source/src/lw/simulation/day.jl"))
input=JSON3.read(read(joinpath(root,mode,"input.json"),String),Dict{String,Any});input["config"]["days"]=day
timing=@timed try
    LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(root,mode,"checkpoints/day-"*lpad(day-1,3,'0')*".jls"))
catch e
    e isa ObserverFinished || rethrow()
end
reference=deserialize(joinpath(root,mode,"checkpoints/day-"*lpad(day,3,'0')*".jls")).state
matched=(counts=actual[][:counts]==reference[:counts],physical=actual[][:daily][end]["physical"]==reference[:daily][end]["physical"],
    events=actual[][:events]==reference[:events],
    loop_rng=all(rand(copy(actual[][:loops][a][g].rng),UInt64,8)==rand(copy(reference[:loops][a][g].rng),UInt64,8)
        for a in LW.IDS for g in keys(reference[:loops][a])),
    plan_rng=all(rand(copy(actual[][:mb_maps][a]["daily_plan"]["rng"]),UInt64,8)==rand(copy(reference[:mb_maps][a]["daily_plan"]["rng"]),UInt64,8) for a in LW.IDS))
observer=actual[][:daily][end]["home_activity"]
@assert observer==actual[][:storage_stats]["home_activity"]
result=(day,mode,matched,seconds=timing.time,observer)
write(joinpath(out,"result.json"),JSON3.write(result))
println(JSON3.write((day,mode,matched,actors=observer["actors"],seconds=timing.time)))
@assert all(values(matched))
