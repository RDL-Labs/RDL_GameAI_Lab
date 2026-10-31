# Trusted local checkpoints; instrumentation is in memory, frozen files stay intact.
using Profile, JSON3, Serialization
length(ARGS)>=2 || error("usage: profile_late.jl RUN NEW_OUTPUT [DAYS...]")
const run=abspath(ARGS[1]);const out=abspath(ARGS[2]);ispath(out) && error("fresh output required");mkpath(out)
const snapshot=joinpath(run,"source")
const warm=Ref(true);const first_sec=Ref(0);const began=Ref(false);const started=Ref(UInt64(0))
const elapsed=Ref(0.);const sleep_seconds=Ref(0.);const checkpoint_seconds=Ref(0.);const daily_seconds=Ref(0.)
const sleep_calls=Ref(0);const actual_counts=Ref{Any}();const actual_physical=Ref{Any}()
struct StopProfile <: Exception end
function tick_probe!(sec)
    if !began[]
        began[]=true;started[]=time_ns();!warm[] && Profile.start_timer()
    end
    warm[] && sec>=first_sec[]+512 && throw(StopProfile())
end
compact_physical(p)=Dict(a=>Dict(k=>v[k] for k in ("body","inventory","personal_stock","position")) for (a,v) in p)
function finish_profile!(daily)
    warm[] && return
    Profile.stop_timer();elapsed[]=(time_ns()-started[])/1e9
    actual_counts[]=deepcopy(daily[end]["counts"])
    actual_physical[]=deepcopy(compact_physical(daily[end]["physical"]))
    throw(StopProfile())
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
const file=joinpath(snapshot,"src/lw/simulation/day.jl")
function edit_once(s,a,b)
    count(a,s)==1 || error("profiling anchor mismatch: $a")
    replace(s,a=>b)
end
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
source=edit_once(source,"now=sec*1_000_000;w.seconds=sec","now=sec*1_000_000;w.seconds=sec\n        Main.tick_probe!(sec)")
source=edit_once(source,"callback=(harvest_sleep || general_sleep || relations!==nothing) ? ((c,t)->begin",
    "callback=(harvest_sleep || general_sleep || relations!==nothing) ? ((c,t)->begin\n                    profile_sleep_start=time_ns()")
anchor="relations!==nothing && social_mb_sleep_review!(relations[a],day,t;completed=true)"
source=edit_once(source,anchor,anchor*"\n                    Main.sleep_seconds[]+=(time_ns()-profile_sleep_start)/1e9;Main.sleep_calls[]+=1")
source=edit_once(source,"if mod(now+1_000_000,clock.day_us)==0","if mod(now+1_000_000,clock.day_us)==0\n            profile_daily_start=time_ns()")
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
source=edit_once(source,anchor,"Main.daily_seconds[]+=(time_ns()-profile_daily_start)/1e9\n            profile_save_start=time_ns()\n            "*anchor*
    "\n            Main.checkpoint_seconds[]+=(time_ns()-profile_save_start)/1e9\n            Main.finish_profile!(daily)")
write(joinpath(out,"instrumented_day.jl"),source) # CPU line numbers refer to this in-memory version.
Base.include_string(Main,source,file)
const input=JSON3.read(read(joinpath(run,"input.json"),String))
Profile.init(n=12_000_000,delay=.005)
reports=Any[]
for day in (length(ARGS)>2 ? parse.(Int,ARGS[3:end]) : [30,174])
    checkpoint=joinpath(run,"checkpoints","day-"*lpad(day-1,3,'0')*".jls")
    for warming in (true,false)
        warm[]=warming;began[]=false;first_sec[]=(day-1)*div(input.clock.day_us,1_000_000)
        sleep_seconds[]=0.;daily_seconds[]=0.;checkpoint_seconds[]=0.;sleep_calls[]=0
        GC.gc();Profile.clear();println("day $day warm=$warming");flush(stdout)
        measured=@timed try
            run_integrated(input;resume_from=checkpoint,checkpoint_dir=warming ? nothing : joinpath(out,"day$day"))
            error("profiling stop missing")
        catch e
            e isa StopProfile || rethrow()
        finally
            Profile.stop_timer()
        end
        warming && continue
        for format in (:flat,:tree)
            open(joinpath(out,"day$day-cpu-$format.txt"),"w") do io
                Profile.print(IOContext(io,:displaysize=>(10000,320));format=format,sortedby=:count,mincount=5)
            end
        end
        original=deserialize(joinpath(run,"checkpoints","day-"*lpad(day,3,'0')*".jls"))
        @assert actual_counts[]==original.state[:daily][end]["counts"]
        @assert actual_physical[]==compact_physical(original.state[:daily][end]["physical"])
        original=nothing
        row=Dict("day"=>day,"seconds"=>elapsed[],"sleep_callback_seconds"=>sleep_seconds[],"sleep_calls"=>sleep_calls[],
            "day_end_before_save_seconds"=>daily_seconds[],"checkpoint_seconds"=>checkpoint_seconds[],
            "ordinary_tick_seconds"=>elapsed[]-sleep_seconds[]-daily_seconds[]-checkpoint_seconds[],
            "call_including_restore_seconds"=>measured.time,"call_allocated_bytes"=>measured.bytes,"call_gc_seconds"=>measured.gctime,
            "checkpoint_bytes"=>filesize(joinpath(out,"day$day/day-"*lpad(day,3,'0')*".jls")),
            "original_counts_and_physical_equal"=>true,"sample_delay_seconds"=>.005)
        push!(reports,row);write(joinpath(out,"report.json"),JSON3.write(reports));println(JSON3.write(row));flush(stdout)
    end
end
