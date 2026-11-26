using JSON3, Serialization, Test
const FIT_BENCH_ROOT=abspath(ARGS[1]);const FIT_BENCH_DAY=parse(Int,ARGS[2]);const FIT_BENCH_OUT=abspath(ARGS[3])
ispath(FIT_BENCH_OUT) && error("fresh output required");mkpath(FIT_BENCH_OUT)
include(joinpath(FIT_BENCH_ROOT,"source/integrations/lightweight_julia/native.jl"))
include("recognition_fit_workspace.jl")
fit_trial_install!(FIT_BENCH_ROOT)
const FIT_BENCH_WARM=Ref(true);const FIT_BENCH_TICKS=Ref(0);const FIT_BENCH_START=Ref(UInt64(0))
const FIT_BENCH_TIMES=Dict{String,Float64}()
struct FitBenchWarmEnd <: Exception end
function fit_bench_tick!()
    FIT_BENCH_TICKS[]+=1
    FIT_BENCH_TICKS[]==1 && (FIT_BENCH_START[]=time_ns())
    FIT_BENCH_WARM[] && FIT_BENCH_TICKS[]>512 && throw(FitBenchWarmEnd())
end
fit_bench_file=joinpath(FIT_BENCH_ROOT,"source/src/lw/simulation/day.jl")
fit_bench_source=replace(read(fit_bench_file,String),r"(?m)^include.*\r?\n"=>"")
fit_bench_anchor="now=sec*1_000_000;w.seconds=sec"
@assert count(fit_bench_anchor,fit_bench_source)==1
fit_bench_source=replace(fit_bench_source,fit_bench_anchor=>fit_bench_anchor*";Main.fit_bench_tick!()")
fit_bench_anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
@assert count(fit_bench_anchor,fit_bench_source)==1
fit_bench_source=replace(fit_bench_source,fit_bench_anchor=>"fit_save_ns=time_ns();"*fit_bench_anchor*";Main.FIT_BENCH_TIMES[\"save_seconds\"]=(time_ns()-fit_save_ns)/1e9;Main.FIT_BENCH_TIMES[\"tick_save_seconds\"]=(time_ns()-Main.FIT_BENCH_START[])/1e9")
Base.include_string(Main,fit_bench_source,fit_bench_file)
fit_bench_input=JSON3.read(read(joinpath(FIT_BENCH_ROOT,"input.json"),String),Dict{String,Any});fit_bench_input["config"]["days"]=FIT_BENCH_DAY
const FIT_BENCH_INPUT=JSON3.read(JSON3.write(fit_bench_input))
const FIT_BENCH_CHECKPOINT=joinpath(FIT_BENCH_ROOT,"checkpoints/day-"*lpad(FIT_BENCH_DAY-1,3,'0')*".jls")
for enabled in (false,true)
    FIT_TRIAL_ENABLED[]=enabled;empty!(FIT_TRIAL_WORKSPACES);FIT_BENCH_TICKS[]=0
    println("warmup cache=",enabled);flush(stdout)
    try
        run_integrated(FIT_BENCH_INPUT;resume_from=FIT_BENCH_CHECKPOINT)
        error("missing warmup stop")
    catch e
        e isa FitBenchWarmEnd || rethrow()
    end
end
FIT_BENCH_WARM[]=false
fit_bench_metrics=Any[]
for (label,enabled) in (("before",false),("after",true))
    FIT_TRIAL_ENABLED[]=enabled;empty!(FIT_TRIAL_WORKSPACES);FIT_BENCH_TICKS[]=0;empty!(FIT_BENCH_TIMES);GC.gc()
    println("measure ",label);flush(stdout)
    timing=@timed run_integrated(FIT_BENCH_INPUT;resume_from=FIT_BENCH_CHECKPOINT,checkpoint_dir=joinpath(FIT_BENCH_OUT,label))
    row=(label=label,call_seconds=timing.time,times=copy(FIT_BENCH_TIMES),bytes=timing.bytes,gc_seconds=timing.gctime,compile_seconds=timing.compile_time)
    push!(fit_bench_metrics,row);write(joinpath(FIT_BENCH_OUT,"metrics.json"),JSON3.write(fit_bench_metrics))
    println(JSON3.write(row));flush(stdout)
end
fit_bench_before=deserialize(joinpath(FIT_BENCH_OUT,"before/day-"*lpad(FIT_BENCH_DAY,3,'0')*".jls")).state
fit_bench_after=deserialize(joinpath(FIT_BENCH_OUT,"after/day-"*lpad(FIT_BENCH_DAY,3,'0')*".jls")).state
const FIT_BENCH_DIFFS=String[];const FIT_BENCH_SEEN=Set{Tuple{UInt,UInt}}()
function fit_bench_compare(a,b,path)
    isequal(a,b) && return
    typeof(a)==typeof(b) || (push!(FIT_BENCH_DIFFS,path*": type");return)
    pair=(objectid(a),objectid(b));pair in FIT_BENCH_SEEN && return;push!(FIT_BENCH_SEEN,pair)
    if a isa AbstractDict
        Set(keys(a))==Set(keys(b)) || (push!(FIT_BENCH_DIFFS,path*": keys");return)
        for k in keys(a);fit_bench_compare(a[k],b[k],path*"/"*string(k));end
    elseif a isa AbstractArray
        size(a)==size(b) || (push!(FIT_BENCH_DIFFS,path*": size");return)
        for i in eachindex(a);fit_bench_compare(a[i],b[i],path*"/"*string(i));end
    elseif fieldcount(typeof(a))>0
        for f in fieldnames(typeof(a));fit_bench_compare(getfield(a,f),getfield(b,f),path*"/"*string(f));end
    else
        push!(FIT_BENCH_DIFFS,path)
    end
end
fit_bench_compare(fit_bench_before,fit_bench_after,"state")
write(joinpath(FIT_BENCH_OUT,"differences.json"),JSON3.write(FIT_BENCH_DIFFS))
@test isempty(FIT_BENCH_DIFFS)
for file in (@__FILE__,joinpath(@__DIR__,"recognition_fit_workspace.jl"));cp(file,joinpath(FIT_BENCH_OUT,basename(file)));end
write(joinpath(FIT_BENCH_OUT,"completed.json"),JSON3.write((day=FIT_BENCH_DAY,checkpoint_fields_equal=true,note="recursive field-value comparison, including stored RNG; alias topology not compared")))
println("completed");flush(stdout)
