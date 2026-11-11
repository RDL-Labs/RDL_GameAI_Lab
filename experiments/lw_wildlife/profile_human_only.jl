using JSON3, Serialization, Profile
const root=abspath(ARGS[1]); const out=abspath(ARGS[2]); const target=parse(Int,ARGS[3])
ispath(out) && error("fresh output required");mkpath(out)
include(joinpath(root,"source/src/lw/LW.jl"))
const sort_trial=length(ARGS)>=4 && ARGS[4]=="single_sort"
if sort_trial
 # Overlay only the two audited edits on frozen code, excluding unrelated work.
 for (rel,before,after) in (
  ("learning/mb_return_outlook.jl","        sort!(queue,by=x->(x.cost,x.node,x.path_key))\n",""),
  ("learning/mb_map.jl","sort!(queue,by=x->(x.cost,x.path_key));item=popfirst!(queue);expanded+=1","item=popfirst!(queue);expanded+=1"))
  frozen=replace(read(joinpath(root,"source/src/lw",rel),String),"\r\n"=>"\n")
  @assert count(before,frozen)==1
  Base.include_string(LW,replace(frozen,before=>after),joinpath(root,"source/src/lw",rel))
 end
end
const rest_trial=length(ARGS)>=4 && ARGS[4]=="rest"
const quiet_trial=length(ARGS)>=4 && ARGS[4]=="quiet_home"
const fatigue_trial=length(ARGS)>=4 && ARGS[4]=="fatigue"
const hunger_trial=length(ARGS)>=4 && ARGS[4] in ("hunger","fatigue")
if hunger_trial
 for rel in ("decision/food_body.jl","decision/food_desire.jl","learning/mb_daily_plan.jl","decision/fatigue_forecast.jl","configured_paths/routine_actions.jl")
  Base.include(LW,joinpath(@__DIR__,"../../src/lw",rel))
 end
end
quiet_trial && Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/routine_actions.jl"))
rest_trial && Base.include(LW,joinpath(@__DIR__,"../../src/lw/decision/task_focus.jl"))
const warming=Ref(true);const ticks=Ref(0);const started=Ref(UInt64(0));const timers=Dict{String,Float64}();const actual=Ref{Any}()
struct Done <: Exception end
function tick!(thinking,sleeping,paused,focused)
 ticks[]+=1
 if ticks[]==1;started[]=time_ns();!warming[] && Profile.start_timer();end
 warming[] && ticks[]>512 && throw(Done())
 for (k,ids) in (("thinking",thinking),("sleeping",sleeping),("paused",paused),("focused",focused))
  for a in ids;key=k*":"*a;timers[key]=get(timers,key,0.)+1;end
 end
end
function finish!(state)
 Profile.stop_timer();timers["day_seconds"]=(time_ns()-started[])/1e9
 actual[]=state;throw(Done())
end
function once(s,a,b)
 @assert count(a,s)==1 a
 replace(s,a=>b)
end
const file=joinpath(root,"source/src/lw/simulation/day.jl")
s=replace(read(hunger_trial ? joinpath(@__DIR__,"../../src/lw/simulation/day.jl") : file,String),r"(?m)^include.*\r?\n"=>"")
hunger_trial && !fatigue_trial && (s=once(s,"get(spec,:fatigue_forecast,true)","false"))
a="thinking_ids=Tuple(a for a in IDS if !(a in paused_ids) && !(a in sleeping_ids) && !(a in collapsed_ids) && !(a in focused_ids))"
s=once(s,a,a*";Main.tick!(thinking_ids,sleeping_ids,paused_ids,focused_ids)")
a="callback=(harvest_sleep || general_sleep || relations!==nothing) ? ((c,t)->begin"
s=once(s,a,a*"\n sleep_profile_ns=time_ns()")
a="relations!==nothing && social_mb_sleep_review!(relations[a],day,t;completed=true)"
s=once(s,a,a*"\n Main.timers[\"sleep_seconds\"]=get(Main.timers,\"sleep_seconds\",0.)+(time_ns()-sleep_profile_ns)/1e9")
a="if mod(now+1_000_000,clock.day_us)==0"
s=once(s,a,a*"\n daily_profile_ns=time_ns()")
a="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
save_call=(rest_trial || quiet_trial || hunger_trial || sort_trial) ? replace(a,"checkpoint_code)"=>"checkpoint_code*\":attention-trial\")") : a
s=once(s,a,"Main.timers[\"daily_seconds\"]=(time_ns()-daily_profile_ns)/1e9;save_profile_ns=time_ns();"*save_call*";Main.timers[\"save_seconds\"]=(time_ns()-save_profile_ns)/1e9;Main.finish!(@lw_capture())")
write(joinpath(out,"instrumented_day.jl"),s);Base.include_string(LW,s,file)
input=JSON3.read(read(joinpath(root,"run/input.json"),String),Dict{String,Any});input["config"]["days"]=target
Profile.init(n=12_000_000,delay=.005)
for warm in (true,false)
 warming[]=warm;ticks[]=0;empty!(timers);GC.gc();Profile.clear()
 println("PROFILE warm=",warm);flush(stdout)
 m=@timed try
  LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(root,"run/checkpoints/day-"*lpad(target-1,3,'0')*".jls"),checkpoint_dir=joinpath(out,warm ? "warm" : "checkpoints"))
 catch e
  e isa Done || rethrow()
 finally
  Profile.stop_timer()
 end
 warm && continue
 for fmt in (:flat,:tree)
  open(joinpath(out,"cpu-$fmt.txt"),"w") do io
   Profile.print(IOContext(io,:displaysize=>(10000,350));format=fmt,sortedby=:count,mincount=8)
  end
 end
 reference_path=joinpath(root,"run/checkpoints/day-"*lpad(target,3,'0')*".jls")
 prior=deserialize(joinpath(root,"run/checkpoints/day-"*lpad(target-1,3,'0')*".jls")).state
 action_counts=Dict(a=>Dict(k=>n-get(prior[:counts][a],k,0) for (k,n) in ac) for (a,ac) in actual[][:counts])
 matched=if isfile(reference_path)
  reference=deserialize(reference_path).state
  (counts=actual[][:counts]==reference[:counts],physical=actual[][:daily][end]["physical"]==reference[:daily][end]["physical"],events=actual[][:events]==reference[:events],home_activity=actual[][:storage_stats]["home_activity"]==reference[:storage_stats]["home_activity"])
 else
  # Odd days now retain a daily summary but not a full restart state.
  reference_day=JSON3.read(read(joinpath(root,"run/day-$target.json"),String),Dict{String,Any})
  (counts=all(action_counts[a]==reference_day["humans"][a]["actions"] for a in LW.IDS),
   physical=all(all(actual[][:daily][end]["physical"][a][k]==reference_day["humans"][a][v] for (k,v) in (("body","body"),("position","position"),("inventory","inventory"),("personal_stock","stock"))) for a in LW.IDS),
   events=nothing,home_activity=actual[][:daily][end]["home_activity"]==reference_day["home_activity"])
 end
 today_events=[e for e in actual[][:events] if (target-1)*input["clock"]["day_us"]<=get(e,"us",0)<target*input["clock"]["day_us"]]
 write(joinpath(out,"day-events.json"),JSON3.write(today_events))
 result=(day=target,rest_trial,quiet_trial,hunger_trial,fatigue_trial,sort_trial,timing=copy(timers),matched,call_seconds=m.time,allocated_bytes=m.bytes,gc_seconds=m.gctime,
     fatigue=fatigue_trial ? Dict(a=>get(m,"fatigue_forecast",nothing) for (a,m) in actual[][:mb_maps]) : nothing,
     hunger=hunger_trial ? actual[][:hunger] : nothing,
     actions=action_counts,physical=actual[][:daily][end]["physical"],home_activity=actual[][:storage_stats]["home_activity"])
 write(joinpath(out,"result.json"),JSON3.write(result));println(JSON3.write((day=target,rest_trial,quiet_trial,hunger_trial,timing=timers,matched)));(rest_trial || quiet_trial || hunger_trial) || @assert all(v===nothing || v for v in values(matched))
end
