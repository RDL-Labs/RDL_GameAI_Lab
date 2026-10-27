using Profile, JSON3
const run=abspath(ARGS[1]);const out=abspath(ARGS[2]);mkpath(out)
const snapshot=joinpath(run,"source")
const warm=Ref(true);const first_sec=Ref(0);const began=Ref(false);const started=Ref(UInt64(0))
const elapsed=Ref(0.);const sleep_seconds=Ref(0.);const checkpoint_seconds=Ref(0.);const daily_seconds=Ref(0.)
const sleep_calls=Ref(0);const saved_counts=Ref{Any}()
struct StopProfile <: Exception end
function gate_probe!(sec,w,purposes,counts,home)
 if !began[]
  began[]=true;started[]=time_ns();!warm[] && Profile.start_timer()
 end
 warm[] && sec>=first_sec[]+512 && throw(StopProfile())
end
function finish_day!(counts)
 warm[] && return
 Profile.stop_timer();elapsed[]=(time_ns()-started[])/1e9;saved_counts[]=deepcopy(counts)
 throw(StopProfile())
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
file=joinpath(snapshot,"src/lw/simulation/day.jl")
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
function edit_once(s,a,b)
 @assert count(a,s)==1
 replace(s,a=>b)
end
source=edit_once(source,"callback=(harvest_sleep || general_sleep) ? ((c,t)->begin",
 "callback=(harvest_sleep || general_sleep) ? ((c,t)->begin\n                    profile_sleep_start=time_ns()")
source=edit_once(source,"sleep_maintenance && enroll_sleep_usage!(action_models[a],t)",
 "sleep_maintenance && enroll_sleep_usage!(action_models[a],t)\n                    Main.sleep_seconds[]+=(time_ns()-profile_sleep_start)/1e9;Main.sleep_calls[]+=1")
source=edit_once(source,"if mod(now+1_000_000,clock.day_us)==0",
 "if mod(now+1_000_000,clock.day_us)==0\n            profile_daily_start=time_ns()")
line="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
source=edit_once(source,line,
 "Main.daily_seconds[]+=(time_ns()-profile_daily_start)/1e9\n            profile_save_start=time_ns()\n            "*line*
 "\n            Main.checkpoint_seconds[]+=(time_ns()-profile_save_start)/1e9\n            Main.finish_day!(counts)")
Base.include_string(Main,source,file)
input=JSON3.read(read(joinpath(run,"ordinary/input.json"),String))
Profile.init(n=20_000_000,delay=.002)
reports=Any[]
for day in (2,45,90)
 checkpoint=joinpath(run,"ordinary/checkpoints/day-"*lpad(day-1,3,'0')*".jls")
 for warming in (true,false)
  warm[]=warming;began[]=false;first_sec[]=(day-1)*17280
  sleep_seconds[]=0.;daily_seconds[]=0.;checkpoint_seconds[]=0.;sleep_calls[]=0
  GC.gc();Profile.clear()
  println("day ",day," warm=",warming);flush(stdout)
  try
   run_integrated(input;resume_from=checkpoint,checkpoint_dir=warming ? nothing : joinpath(out,"day$day"))
   error("missing profiling stop")
  catch e
   e isa StopProfile || rethrow()
  finally
   Profile.stop_timer()
  end
 end
 for format in (:flat,:tree)
  open(joinpath(out,"day$day-cpu-$format.txt"),"w") do io
   Profile.print(IOContext(io,:displaysize=>(10000,320));format=format,sortedby=:count,mincount=5)
  end
 end
 original=JSON3.read(read(joinpath(run,"ordinary/run/result.json"),String))
 @assert JSON3.write(saved_counts[])==JSON3.write(original.daily[day].counts)
 row=Dict("day"=>day,"seconds"=>elapsed[],"sleep_callback_seconds"=>sleep_seconds[],"sleep_calls"=>sleep_calls[],
 "day_end_before_save_seconds"=>daily_seconds[],"checkpoint_seconds"=>checkpoint_seconds[],
 "checkpoint_bytes"=>filesize(joinpath(out,"day$day/day-"*lpad(day,3,'0')*".jls")))
 push!(reports,row);write(joinpath(out,"report.json"),JSON3.write(reports));println(JSON3.write(row));flush(stdout)
end
