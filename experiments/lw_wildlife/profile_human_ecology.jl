# Read-only replay of a trusted frozen integrated run. Instrumentation is in memory.
using JSON3,Serialization,Profile
const run=abspath(ARGS[1]);const out=abspath(ARGS[2]);const target_day=parse(Int,ARGS[3])
ispath(out) && error("fresh output required");mkpath(out)
const frozen_root=joinpath(run,"source")
const boundary_trial=length(ARGS)>=4 ? ARGS[4] : "original"
boundary_trial in ("original","baseline","boxes") || error("boundary trial mode")
const box_trial=boundary_trial=="boxes"
const longrun=length(ARGS)>=5
const run_days=longrun ? parse(Int,ARGS[5]) : 1
run_days>0 || error("positive run days required")
const final_day=target_day+run_days-1
const completed_day=Ref(target_day-1)
const daily_measurements=Any[]
include(joinpath(frozen_root,"experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(frozen_root,"experiments/lw_wildlife/proximity_observer.jl"))
include(joinpath(frozen_root,"src/lw/configured_paths/rabbit_distributed_layout.jl"))
include(joinpath(frozen_root,"src/lw/configured_paths/predator_population_exchange.jl"))
include(joinpath(frozen_root,"src/lw/configured_paths/raptor_trial.jl"))
const human_input=JSON3.read(read(joinpath(run,"input.json"),String),Dict{String,Any})
const human_roster=String.(human_input["scene"]["experimental_actor_ids"])
const current_ecology=true;const integrated_ecology_setup=(rabbits=150,predators=1,grass_scale=1.5,prey_nutrition=1.)
const integrated_predator_count=1;const selected_donor=0;const inherited_source=nothing;const inherited_pursuits=nothing
const human_scent_enabled=true;const rabbit_approach_enabled=true;const integrated_output=out
const bridge_started=time()
integrated_ticks(start_sec,days,clock)=start_sec:days*div(clock.day_us,1_000_000)-1
bridge=read(joinpath(frozen_root,"experiments/lw_wildlife/humans_learned_predators.jl"),String)
definitions=split(split(bridge,"function integrated_predator_cohort";limit=2)[2],"const bridge_conditions";limit=2)[1]
Base.include_string(Main,"function integrated_predator_cohort"*definitions,"profile_bridge.jl")
const warming=Ref(true);const began=Ref(false);const start_ns=Ref(UInt64(0));const timer=Dict{String,Float64}()
const actual=Ref{Any}();const tick_count=Ref(0)
struct ProfileDone <: Exception end
function probe_tick!()
    if !began[];began[]=true;start_ns[]=time_ns();!warming[] && !longrun && Profile.start_timer();end
    tick_count[]+=1
    warming[] && tick_count[]>512 && throw(ProfileDone())
end
function finish_probe!(daily)
    !longrun && Profile.stop_timer();timer["total_tick_and_daily_seconds"]=(time_ns()-start_ns[])/1e9
    if longrun
        completed_day[]=length(daily)
        current=daily[end];previous=daily[end-1]
        humans=Dict{String,Any}()
        for (actor,counts) in current["counts"]
            actions=Dict(k=>n-get(previous["counts"][actor],k,0) for (k,n) in counts)
            @assert sum(values(actions))==17280
            physical=current["physical"][actor]
            humans[actor]=(actions,body=physical["body"],position=physical["position"],
                inventory=physical["inventory"],stock=physical["personal_stock"],
                legacy_return_completed=physical["return_purpose"]["completed"]-previous["physical"][actor]["return_purpose"]["completed"],
                return_active=physical["return_purpose"]["active"])
        end
        record=(day=completed_day[],boundary_trial,timing=copy(timer),humans,home_activity=get(current,"home_activity",nothing))
        push!(daily_measurements,record)
        write(joinpath(out,"day-$(completed_day[]).json"),JSON3.write(record))
        write(joinpath(out,"progress.json"),JSON3.write((day=completed_day[],completed=length(daily_measurements),requested=run_days,boundary_trial,timing=copy(timer))))
        println("BOUNDARY_DAY ",JSON3.write((day=completed_day[],boundary_trial,seconds=timer["total_tick_and_daily_seconds"])));flush(stdout)
        if completed_day[]>=final_day || isfile(joinpath(out,"STOP")) || isfile(joinpath(dirname(out),"STOP"))
            throw(ProfileDone())
        end
        empty!(timer);start_ns[]=time_ns()
        return
    end
    actual[]=(counts=deepcopy(daily[end]["counts"]),physical=deepcopy(daily[end]["physical"]),wildlife=deepcopy(daily[end]["wildlife"]))
    throw(ProfileDone())
end
function once(s,a,b)
    count(a,s)==1 || error("anchor: $a")
    replace(s,a=>b)
end
function timed_line(s,line,key)
    once(s,line,"profile_section_start=time_ns(); "*line*"; Main.timer[\"$key\"]=get(Main.timer,\"$key\",0.)+(time_ns()-profile_section_start)/1e9")
end
const day_file=joinpath(frozen_root,"src/lw/simulation/day.jl")
source=replace(read(day_file,String),r"(?m)^include.*\r?\n"=>"")
if boundary_trial!="original"
    for file in ("local_structures.jl","rho_map.jl")
        trial_source=read(joinpath(@__DIR__,"../../src/lw/perception",file),String)
        write(joinpath(out,file),trial_source)
        Base.include_string(LW,trial_source,joinpath(out,file))
    end
    global source=once(source,
        "rho_baselines[a]=rho_profile==\"home-distance\" ? home_distance_profile!(mb_maps[a][\"home_distance\"],get(ground_receipts,a,nothing)) : rho_profile",
        "rho_baselines[a]=rho_profile==\"home-distance\" ? home_distance_profile!(mb_maps[a][\"home_distance\"],get(ground_receipts,a,nothing)) : rho_profile\n if Main.box_trial && rho_profile!=\"off\"; rho_baselines[a]=rho_box_profile(get(mb_maps[a],\"home_distance\",D()),get(ground_receipts,a,nothing);explicit_fine=rho_profile==\"fine\"); end")
    global source=once(source,"goal_arrival_rho(arrival,baseline)","(Main.box_trial ? baseline : goal_arrival_rho(arrival,baseline))")
    global source=once(source,"rho_map(view,lateral_views[a],effective)","rho_observed_map!(ground_models[a][\"structures\"],view,lateral_views[a],effective;boxes=Main.box_trial)")
    global source=once(source,"ground_receipts[a]=D(\"actor\"=>a,","ground_receipts[a]=D(\"action\"=>action,\"status\"=>status,\"actor\"=>a,")
    # Count actual recognition profiles, outside saved simulation state.
    global source=once(source,"update_structures!(ground_models[a][\"structures\"],structure,receipt)",
        "update_structures!(ground_models[a][\"structures\"],structure,receipt); Main.timer[\"rho_\"*effective*\"_calls\"]=get(Main.timer,\"rho_\"*effective*\"_calls\",0.)+1")
end
source=once(source,"check(days isa Int && 1<=days<=180,\"lw_days\")","check(days isa Int && days>0,\"lw_days\")")
source=once(source,"@lw_restore saved.state","@lw_restore saved.state\n Main.H.enable_rabbit_neighbor_batch!(wildlife.world;gpu=true,audit=false,automatic=true)\n Main.P.configured_predator_terrain_enable!(wildlife.world;enabled=true)")
source=once(source,"now=sec*1_000_000;w.seconds=sec","now=sec*1_000_000;w.seconds=sec; Main.probe_tick!()")
for (line,key) in (
 ("wildlife!==nothing && Main.integrated_predator_prepare!(wildlife,predator_cohort,[w.positions[a] for a in IDS],sec,visual_illumination)","animal_prepare_seconds"),
 ("wildlife!==nothing && Main.integrated_predator_advance!(wildlife,predator_cohort,sec)","animal_advance_seconds"),
 ("wildlife_motion_samples=Main.integrated_predator_motion(wildlife_motion_objects(wildlife,wildlife_previous_positions),predator_cohort)","animal_motion_seconds"))
 global source=timed_line(source,line,key)
end
source=once(source,"callback=(harvest_sleep || general_sleep || relations!==nothing) ? ((c,t)->begin","callback=(harvest_sleep || general_sleep || relations!==nothing) ? ((c,t)->begin\n profile_sleep_start=time_ns()")
anchor="relations!==nothing && social_mb_sleep_review!(relations[a],day,t;completed=true)"
source=once(source,anchor,anchor*"\n Main.timer[\"sleep_seconds\"]=get(Main.timer,\"sleep_seconds\",0.)+(time_ns()-profile_sleep_start)/1e9")
source=once(source,"if mod(now+1_000_000,clock.day_us)==0","if mod(now+1_000_000,clock.day_us)==0\n profile_daily_start=time_ns()")
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
save_anchor=longrun ? replace(anchor,"checkpoint_code)"=>"checkpoint_code*\":boundary-$boundary_trial\")") : anchor
source=once(source,anchor,"Main.timer[\"daily_before_save_seconds\"]=(time_ns()-profile_daily_start)/1e9\n profile_save_start=time_ns()\n "*save_anchor*"\n Main.timer[\"checkpoint_seconds\"]=(time_ns()-profile_save_start)/1e9\n Main.finish_probe!(daily)")
write(joinpath(out,"instrumented_day.jl"),source)
Base.include_string(LW,source,day_file)
human_input["config"]["days"]=final_day
const input=JSON3.read(JSON3.write(human_input))
const checkpoint=joinpath(run,"checkpoints/day-"*lpad(target_day-1,3,'0')*".jls")
!longrun && Profile.init(n=12_000_000,delay=.005)
for warm in (true,false)
 warming[]=warm;began[]=false;tick_count[]=0;empty!(timer);GC.gc();!longrun && Profile.clear()
 println("PROFILE warm=$warm day=$target_day");flush(stdout)
 measured=@timed try
    LW.run_integrated(input;resume_from=checkpoint,checkpoint_dir=joinpath(out,warm ? "warm-checkpoints" : "checkpoints"))
 catch e
    e isa ProfileDone || rethrow()
 finally
    !longrun && Profile.stop_timer()
 end
 warm && continue
 if longrun
    finished=completed_day[]==final_day
    record=(completed=finished,stop_reason=finished ? "requested_days" : "manual_stop",boundary_trial,
        first_day=target_day,last_day=completed_day[],requested_days=run_days,completed_days=length(daily_measurements),
        total_simulation_seconds=sum(r.timing["total_tick_and_daily_seconds"] for r in daily_measurements),
        call_seconds_including_restore=measured.time,allocated_bytes=measured.bytes,gc_seconds=measured.gctime)
    write(joinpath(out,"completed.json"),JSON3.write(record))
    println(JSON3.write(record));flush(stdout)
    continue
 end
 for fmt in (:flat,:tree)
    open(joinpath(out,"cpu-$fmt.txt"),"w") do io
        Profile.print(IOContext(io,:displaysize=>(10000,350));format=fmt,sortedby=:count,mincount=8)
    end
 end
 write(joinpath(out,"timing-before-verification.json"),JSON3.write((day=target_day,timing=copy(timer),call_seconds=measured.time,allocated_bytes=measured.bytes,gc_seconds=measured.gctime)))
 GC.gc()
 expected=deserialize(joinpath(run,"checkpoints/day-"*lpad(target_day,3,'0')*".jls"))
 reference=expected.state[:daily][end]
 previous_counts=expected.state[:daily][end-1]["counts"]
 daily_action_counts=Dict(a=>Dict(k=>n-get(previous_counts[a],k,0) for (k,n) in actor_counts) for (a,actor_counts) in actual[].counts)
 matched=(counts=actual[].counts==reference["counts"],physical=actual[].physical==reference["physical"],wildlife=actual[].wildlife==reference["wildlife"])
 result=(day=target_day,boundary_trial,timing=copy(timer),call_seconds=measured.time,allocated_bytes=measured.bytes,gc_seconds=measured.gctime,matched,daily_action_counts,actual=actual[])
 write(joinpath(out,"result.json"),JSON3.write(result));println(JSON3.write((day=target_day,boundary_trial,timing=copy(timer),matched)));flush(stdout)
end
