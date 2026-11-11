using JSON3, Serialization, SHA
const replay_root=abspath(ARGS[1]); const replay_out=abspath(ARGS[2])
const replay_day=parse(Int,ARGS[3]); const replay_mode=ARGS[4]
replay_mode in ("baseline","audit","merged","paired") || error("mode")
ispath(replay_out) && error("fresh output required");mkpath(replay_out)
include(joinpath(replay_root,"source/src/lw/LW.jl"))
const replay_warm=Ref(true);const replay_ticks=Ref(0);const replay_start=Ref(UInt64(0))
const replay_merge=Ref(false);const replay_destination=Ref(replay_out)
const replay_timers=Dict{String,Float64}();const replay_state=Ref{Any}()
const validation_stats=Dict{String,Float64}();const validation_seen=Set{Any}()
const validation_global_nodes=Set{Tuple{String,String}}()
increment!(key,n=1)=validation_stats[key]=get(validation_stats,key,0.)+n
function validation_begin!()
    empty!(validation_seen);increment!("projection_calls")
end
function validation_estimate(s,state,key)
    increment!("calls")
    repeated=key in validation_seen
    repeated && increment!("duplicate_calls")
    push!(validation_seen,key)
    key===nothing ? increment!("null_key_calls") : push!(validation_global_nodes,(s["actor"],key))
    steps=0;node=key;r=key===nothing ? nothing : get(state["paths"],key,nothing)
    if r!==nothing
        for id in r["path"]
            steps+=1;e=get(s["edges"],id,nothing)
            (e===nothing || e["from"]!=node) && break
            node=e["to"]
        end
    end
    increment!("edges_checked",steps);repeated && increment!("duplicate_edges",steps)
    measured=@timed LW.mb_return_estimate(s,state,key)
    increment!("validation_seconds",measured.time);increment!("validation_bytes",measured.bytes)
    measured.value===nothing && increment!("unknown_calls")
    repeated && measured.value===nothing && increment!("duplicate_unknown_calls")
    measured.value
end
if replay_mode=="audit"
    code=read(joinpath(replay_root,"source/src/lw/learning/mb_return_outlook.jl"),String)
    part="function mb_project_return!"*last(split(code,"function mb_project_return!"))
    part=replace(part,"current=mb_return_estimate(s,state,frame.key)"=>"Main.validation_begin!();current=Main.validation_estimate(s,state,frame.key)",
        "r=mb_return_estimate(s,state,key)"=>"r=Main.validation_estimate(s,state,key)")
    Base.include_string(LW,part)
elseif replay_mode in ("merged","paired")
    include("queue_merge_overlay.jl")
    overlay=queue_merge_overlay(joinpath(replay_root,"source/src/lw/learning"),joinpath(replay_out,"overlay"))
    if replay_mode=="paired"
        for (name,new,old) in (
            ("mb_map.jl","mb_queue_merge!(queue,queue_prefix_length,64,x->(x.cost,x.path_key))","sort!(queue,by=x->(x.cost,x.path_key));length(queue)>64 && resize!(queue,64)"),
            ("mb_return_outlook.jl","mb_queue_merge!(queue,queue_prefix_length,256,x->(x.cost,x.node,x.path_key))","sort!(queue,by=x->(x.cost,x.node,x.path_key));length(queue)>256 && resize!(queue,256)"))
            path=joinpath(overlay,name);source=read(path,String);@assert count(new,source)==1
            write(path,replace(source,new=>"if Main.replay_merge[]; $new; else; $old; end"))
        end
    end
    Base.include(LW,joinpath(overlay,"mb_map.jl"))
    Base.include(LW,joinpath(overlay,"mb_return_outlook.jl"))
end
struct ReplayDone <: Exception end
function replay_tick!(thinking,sleeping,paused,focused)
    replay_ticks[]+=1
    replay_ticks[]==1 && (replay_start[]=time_ns())
    replay_warm[] && replay_mode!="paired" && replay_ticks[]>512 && throw(ReplayDone())
    for (label,actors) in (("thinking",thinking),("sleeping",sleeping),("paused",paused),("focused",focused)), actor in actors
        key=label*":"*actor;replay_timers[key]=get(replay_timers,key,0.)+1
    end
end
function replay_finish!(state,save_seconds)
    replay_timers["day_seconds"]=(time_ns()-replay_start[])/1e9
    replay_timers["save_seconds"]=save_seconds
    replay_state[]=state;throw(ReplayDone())
end
function replace_once(code,anchor,replacement)
    @assert count(anchor,code)==1 anchor
    replace(code,anchor=>replacement)
end
day_file=joinpath(replay_root,"source/src/lw/simulation/day.jl")
code=replace(read(day_file,String),r"(?m)^include.*\r?\n"=>"")
anchor="thinking_ids=Tuple(a for a in IDS if !(a in paused_ids) && !(a in sleeping_ids) && !(a in collapsed_ids) && !(a in focused_ids))"
code=replace_once(code,anchor,anchor*";Main.replay_tick!(thinking_ids,sleeping_ids,paused_ids,focused_ids)")
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
code=replace_once(code,anchor,"replay_save_start=time_ns();if !Main.replay_warm[];"*anchor*";end;Main.replay_finish!(@lw_capture(),(time_ns()-replay_save_start)/1e9)")
write(joinpath(replay_out,"instrumented_day.jl"),code);Base.include_string(LW,code,day_file)
input=JSON3.read(read(joinpath(replay_root,"run/input.json"),String),Dict{String,Any});input["config"]["days"]=replay_day
write(joinpath(replay_out,"conditions.json"),JSON3.write((root=replay_root,day=replay_day,mode=replay_mode,
    original_checkpoint_sha256=bytes2hex(sha256(read(joinpath(replay_root,"run/checkpoints/day-"*lpad(replay_day-1,3,'0')*".jls")))),
    checkpoint_note="Diagnostic output uses original source identity for loading. Overlaid source is stored separately; not a normal production resume checkpoint.")))
schedule=replay_mode=="paired" ? [(true,false,"warm-baseline"),(true,true,"warm-merged"),(false,false,"baseline-1"),(false,true,"merged-1"),(false,true,"merged-2"),(false,false,"baseline-2")] : [(true,false,"warm"),(false,replay_mode=="merged","measured")]
for (warm,merged,label) in schedule
    replay_merge[]=merged
    replay_destination[]=replay_mode=="paired" ? joinpath(replay_out,label) : replay_out
    mkpath(replay_destination[])
    replay_warm[]=warm;replay_ticks[]=0;empty!(replay_timers);empty!(validation_stats);empty!(validation_global_nodes);GC.gc()
    println("REPLAY ",replay_day," ",replay_mode," ",label," warm=",warm);flush(stdout)
    measured=@timed try
        LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(replay_root,"run/checkpoints/day-"*lpad(replay_day-1,3,'0')*".jls"),checkpoint_dir=joinpath(replay_destination[],"checkpoints"))
    catch exception
        exception isa ReplayDone || rethrow()
    end
    warm && (println("WARM_DONE seconds=",measured.time," compile=",measured.compile_time);flush(stdout);continue)
    result=(day=replay_day,mode=replay_mode=="paired" ? (merged ? "merged" : "baseline") : replay_mode,label,threads=Threads.nthreads(),timing=copy(replay_timers),call_seconds=measured.time,compile_seconds=measured.compile_time,
        allocated_bytes=measured.bytes,gc_seconds=measured.gctime,validation=copy(validation_stats),distinct_actor_nodes=length(validation_global_nodes))
    write(joinpath(replay_destination[],"result.json"),JSON3.write(result));println(JSON3.write(result));flush(stdout)
end
