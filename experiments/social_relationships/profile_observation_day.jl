# Trusted frozen checkpoint replay: CPU sampling, no decision-policy overlay.
using JSON3, Serialization, Profile, Test
length(ARGS)==3 || error("usage ROOT DAY OUTPUT")
const OBS_PROFILE_ROOT=abspath(ARGS[1])
const OBS_PROFILE_DAY=parse(Int,ARGS[2])
const OBS_PROFILE_OUT=abspath(ARGS[3])
ispath(OBS_PROFILE_OUT) && error("fresh output required")
mkpath(OBS_PROFILE_OUT)
include(joinpath(OBS_PROFILE_ROOT,"source/integrations/lightweight_julia/native.jl"))
const OBS_PROFILE_WARM=Ref(true)
const OBS_PROFILE_TICKS=Ref(0)
const OBS_PROFILE_START=Ref(UInt64(0))
const OBS_PROFILE_TIMES=Dict{String,Float64}()
struct ObservationProfileWarmEnd <: Exception end
function observation_profile_tick!()
    OBS_PROFILE_TICKS[]+=1
    if OBS_PROFILE_TICKS[]==1
        OBS_PROFILE_START[]=time_ns()
        OBS_PROFILE_WARM[] || Profile.start_timer()
    end
    OBS_PROFILE_WARM[] && OBS_PROFILE_TICKS[]>512 && throw(ObservationProfileWarmEnd())
end
function observation_profile_end!()
    Profile.stop_timer()
    OBS_PROFILE_TIMES["tick_through_save_seconds"]=(time_ns()-OBS_PROFILE_START[])/1e9
end
function observation_profile_replace(source,before,after)
    count(before,source)==1 || error("anchor mismatch: $before")
    replace(source,before=>after)
end
const OBS_PROFILE_FILE=joinpath(OBS_PROFILE_ROOT,"source/src/lw/simulation/day.jl")
observation_profile_source=replace(read(OBS_PROFILE_FILE,String),r"(?m)^include.*\r?\n"=>"")
observation_profile_source=observation_profile_replace(observation_profile_source,
    "now=sec*1_000_000;w.seconds=sec",
    "now=sec*1_000_000;w.seconds=sec;Main.observation_profile_tick!()")
observation_profile_save="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
observation_profile_source=observation_profile_replace(observation_profile_source,observation_profile_save,
    "observation_profile_save_ns=time_ns();"*observation_profile_save*
    ";Main.OBS_PROFILE_TIMES[\"save_seconds\"]=(time_ns()-observation_profile_save_ns)/1e9;Main.observation_profile_end!()")
write(joinpath(OBS_PROFILE_OUT,"instrumented_day.jl"),observation_profile_source)
Base.include_string(Main,observation_profile_source,OBS_PROFILE_FILE)
observation_profile_input=JSON3.read(read(joinpath(OBS_PROFILE_ROOT,"input.json"),String),Dict{String,Any})
observation_profile_input["config"]["days"]=OBS_PROFILE_DAY
const OBS_PROFILE_INPUT=JSON3.read(JSON3.write(observation_profile_input))
const OBS_PROFILE_CHECKPOINT=joinpath(OBS_PROFILE_ROOT,"checkpoints/day-"*lpad(OBS_PROFILE_DAY-1,3,'0')*".jls")
cp(@__FILE__,joinpath(OBS_PROFILE_OUT,"runner.jl"))
println("warmup 512 ticks");flush(stdout)
try
    run_integrated(OBS_PROFILE_INPUT;resume_from=OBS_PROFILE_CHECKPOINT)
    error("missing warmup stop")
catch e
    e isa ObservationProfileWarmEnd || rethrow()
end
OBS_PROFILE_WARM[]=false;OBS_PROFILE_TICKS[]=0;empty!(OBS_PROFILE_TIMES)
GC.gc();Profile.init(n=20_000_000,delay=.005);Profile.clear()
println("measuring restored day ",OBS_PROFILE_DAY);flush(stdout)
observation_profile_measurement=@timed try
    run_integrated(OBS_PROFILE_INPUT;resume_from=OBS_PROFILE_CHECKPOINT,checkpoint_dir=joinpath(OBS_PROFILE_OUT,"checkpoints"))
finally
    Profile.stop_timer()
end
for fmt in (:flat,:tree)
    open(joinpath(OBS_PROFILE_OUT,"cpu-$fmt.txt"),"w") do io
        Profile.print(IOContext(io,:displaysize=>(10000,500));format=fmt,sortedby=:count,mincount=10)
    end
end
serialize(joinpath(OBS_PROFILE_OUT,"cpu-profile.jls"),Profile.retrieve())
observation_profile_result,observation_profile_summary=observation_profile_measurement.value
observation_profile_original=deserialize(joinpath(OBS_PROFILE_ROOT,"checkpoints/day-"*lpad(OBS_PROFILE_DAY,3,'0')*".jls")).state
observation_profile_same(a,b)=JSON3.read(JSON3.write(a),Any)==JSON3.read(JSON3.write(b),Any)
@testset "observable parity" begin
    @test observation_profile_same(observation_profile_original[:daily][OBS_PROFILE_DAY],observation_profile_result["daily"][OBS_PROFILE_DAY])
    @test observation_profile_same(observation_profile_original[:items]["counts"],observation_profile_result["portable_items"]["counts"])
end
write(joinpath(OBS_PROFILE_OUT,"metrics.json"),JSON3.write((day=OBS_PROFILE_DAY,
    times=OBS_PROFILE_TIMES,call_seconds=observation_profile_measurement.time,
    allocated_bytes=observation_profile_measurement.bytes,gc_seconds=observation_profile_measurement.gctime,
    compile_seconds=observation_profile_measurement.compile_time,threads=Threads.nthreads(),julia=string(VERSION),
    parity="daily and item counts; not full internal state/RNG",warmup_ticks=512,sample_interval_seconds=.005)))
write(joinpath(OBS_PROFILE_OUT,"completed.json"),JSON3.write((day=OBS_PROFILE_DAY,passed=true)))
println("completed");flush(stdout)
