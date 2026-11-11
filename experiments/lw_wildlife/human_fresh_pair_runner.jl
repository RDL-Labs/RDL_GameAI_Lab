# Fresh human-only paired run; source_root and input are frozen by the launcher.
using JSON3, Serialization, SHA
const source_root=abspath(ARGS[1]);const out=abspath(ARGS[2])
const first_day=parse(Int,ARGS[3])
const resume_path=length(ARGS)>=6 ? abspath(ARGS[6]) : nothing
@assert (first_day==1)==(resume_path===nothing)
const mode=ARGS[4];const days=parse(Int,ARGS[5])
# Large restart states every two days; lightweight daily summaries remain daily.
const checkpoint_interval_days=2
mode in ("baseline","boxes") || error("invalid boundary mode")
ispath(out) && error("fresh output required");mkpath(out)
const process_started=time_ns()
include(joinpath(source_root,"src/lw/LW.jl"))
const migrated_resume=if resume_path===nothing
    nothing
else
    saved=deserialize(resume_path)
    @assert saved.day==first_day-1
    @assert saved.julia==string(VERSION)
    # Explicit migration for this experiment only; original state and input identity
    # are preserved. The normal loader still validates identity and field layout.
    old_root=joinpath(dirname(dirname(dirname(resume_path))),"source","src")
    files=sort([joinpath(d,f) for (d,_,fs) in walkdir(old_root) for f in fs if endswith(f,".jl")])
    old_code=bytes2hex(sha256(join([relpath(f,old_root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
    @assert saved.code==old_code
    path=joinpath(out,"resume-migrated.jls")
    serialize(path,merge(saved,(code=LW.checkpoint_code_hash(),)))
    write(joinpath(out,"migration.json"),JSON3.write((original=resume_path,
        original_sha256=bytes2hex(sha256(read(resume_path))),old_code,new_code=LW.checkpoint_code_hash(),
        state_changed=false,first_day)))
    path
end
const spec_input=JSON3.read(read(joinpath(source_root,"input.json"),String),Dict{String,Any})
spec_input["config"]["days"]=days
spec_input["scene"]["rho_box_boundaries"]=mode=="boxes"
@assert spec_input["scene"]["wildlife"]["enabled"]===false
@assert Tuple(spec_input["scene"]["experimental_actor_ids"])==LW.IDS
write(joinpath(out,"input.json"),JSON3.write(spec_input))
const day_started=Ref(UInt64(0));const records=Any[];const completed_day=Ref(0)
struct FreshFinished <: Exception end
function tick_start!()
    day_started[]==0 && (day_started[]=time_ns())
end
function day_finished!(daily,save_seconds,mb_maps)
    elapsed=(time_ns()-day_started[])/1e9
    day=length(daily);current=daily[end]
    humans=Dict{String,Any}()
    for (actor,counts) in current["counts"]
        previous=day==1 ? Dict{String,Int}() : daily[end-1]["counts"][actor]
        actions=Dict(k=>n-get(previous,k,0) for (k,n) in counts)
        @assert sum(values(actions))==17280
        physical=current["physical"][actor]
        previous_returns=day==1 ? 0 : daily[end-1]["physical"][actor]["return_purpose"]["completed"]
        activity=current["home_activity"]["actors"][actor]
        fatigue_state=get(mb_maps[actor],"fatigue_forecast",nothing)
        fatigue= fatigue_state===nothing ? nothing : (continued=get(fatigue_state,"continued",0),rested=get(fatigue_state,"rested",0),
            records=[r for r in fatigue_state["records"] if (day-1)*spec_input["clock"]["day_us"]<=r["us"]<day*spec_input["clock"]["day_us"]])
        focus_state=get(mb_maps[actor],"task_focus",LW.D())
        wait_monitor=(wakeups=copy(get(focus_state,"wakeups",LW.D())),pending=deepcopy(get(focus_state,"wait",nothing)))
        humans[actor]=(body=physical["body"],position=physical["position"],actions,fatigue,wait_monitor,
            inventory=physical["inventory"],stock=physical["personal_stock"],
            returns=activity["returns"],departures=activity["departures"],
            unload_count=activity["unload_count"],unloaded_units=activity["unloaded_units"],
            legacy_return_completed=physical["return_purpose"]["completed"]-previous_returns,
            return_active=physical["return_purpose"]["active"])
    end
    record=(day,mode,total_seconds=elapsed,save_seconds,simulation_seconds=elapsed-save_seconds,humans,
        home_activity=current["home_activity"])
    push!(records,record);completed_day[]=day
    write(joinpath(out,"day-$day.json"),JSON3.write(record))
    write(joinpath(out,"progress.json"),JSON3.write(record))
    println("FRESH_DAY ",JSON3.write((day,mode,total_seconds=elapsed,save_seconds)));flush(stdout)
    if day==days || isfile(joinpath(out,"STOP")) || isfile(joinpath(dirname(out),"STOP")) || isfile(joinpath(dirname(dirname(out)),"STOP"))
        throw(FreshFinished())
    end
    day_started[]=time_ns()
end
function once(source,anchor,replacement)
    count(anchor,source)==1 || error("anchor changed: $anchor")
    replace(source,anchor=>replacement)
end
const day_file=joinpath(source_root,"src/lw/simulation/day.jl")
source=replace(read(day_file,String),r"(?m)^include.*\r?\n"=>"")
source=once(source,"wildlife=LWGrazing.build(spec,clock;low_obstacles)",
    "wildlife=LWGrazing.build(spec,clock;low_obstacles); @assert wildlife===nothing")
source=once(source,"now=sec*1_000_000;w.seconds=sec","now=sec*1_000_000;w.seconds=sec;Main.tick_start!()")
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
source=once(source,anchor,"fresh_save_seconds=0.;if mod(length(daily),Main.checkpoint_interval_days)==0 || length(daily)==Main.days || isfile(joinpath(Main.out,\"STOP\")) || isfile(joinpath(dirname(Main.out),\"STOP\")) || isfile(joinpath(dirname(dirname(Main.out)),\"STOP\"));fresh_save_start=time_ns();"*anchor*";fresh_save_seconds=(time_ns()-fresh_save_start)/1e9;end;Main.day_finished!(daily,fresh_save_seconds,mb_maps)")
write(joinpath(out,"instrumented_day.jl"),source)
Base.include_string(LW,source,day_file)
measured=@timed try
    LW.run_integrated(JSON3.read(JSON3.write(spec_input));checkpoint_dir=joinpath(out,"checkpoints"),resume_from=migrated_resume)
catch exception
    exception isa FreshFinished || rethrow()
end
@assert !isempty(records)
completed=completed_day[]==days
result=(completed,completed_days=length(records),requested_days=days-first_day+1,first_day,last_day=completed_day[],mode,
    stop_reason=completed ? "requested_days" : "manual_stop",total_seconds=sum(r.total_seconds for r in records),
    save_seconds=sum(r.save_seconds for r in records),call_seconds=measured.time,
    process_seconds=(time_ns()-process_started)/1e9,allocated_bytes=measured.bytes,gc_seconds=measured.gctime)
write(joinpath(out,"completed.json"),JSON3.write(result));println(JSON3.write(result))
