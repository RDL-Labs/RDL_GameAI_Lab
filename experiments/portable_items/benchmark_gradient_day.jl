# Trusted local checkpoint replay. Frozen production source is never modified.
using JSON3, SHA, Serialization
length(ARGS)==4 || error("usage: benchmark_gradient_day.jl RUN DAY on|off NEW_OUTPUT")
const run=abspath(ARGS[1]);const day=parse(Int,ARGS[2]);const enabled=ARGS[3]=="on"
ARGS[3] in ("on","off") || error("invalid mode")
const out=abspath(ARGS[4]);ispath(out) && error("fresh output required");mkpath(out)
const snapshot=joinpath(run,"source")
const checkpoint=joinpath(run,"checkpoints","day-"*lpad(day-1,3,'0')*".jls")
const warm=Ref(true);const began=Ref(false);const started=Ref(UInt64(0))
const tick_seconds=Ref(0.);const save_seconds=Ref(0.);const first_sec=Ref(0)
const prior_captured=Dict{String,Int}()
struct StopWarmup <: Exception end
function set_logging!(relations)
    empty!(prior_captured)
    for (a,r) in relations
        prior_captured[a]=get(get(r,"gradient_maps",Dict()),"captured",0)
        r["gradient_logging"]=enabled
    end
end
function tick_probe!(sec)
    if !began[];began[]=true;started[]=time_ns();end
    warm[] && sec>=first_sec[]+512 && throw(StopWarmup())
end
function finish_day!()
    tick_seconds[]=(time_ns()-started[])/1e9
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
file=joinpath(snapshot,"src/lw/simulation/day.jl")
function edit_once(s,a,b)
    count(a,s)==1 || error("instrumentation anchor mismatch: $a")
    replace(s,a=>b)
end
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
source=edit_once(source,"@lw_restore saved.state","@lw_restore saved.state\n        Main.set_logging!(relations)")
source=edit_once(source,"now=sec*1_000_000;w.seconds=sec","now=sec*1_000_000;w.seconds=sec\n        Main.tick_probe!(sec)")
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
source=edit_once(source,anchor,"gradient_save_start=time_ns()\n            "*anchor*"\n            Main.save_seconds[]+=(time_ns()-gradient_save_start)/1e9\n            Main.finish_day!()")
write(joinpath(out,"instrumented_day.jl"),source)
Base.include_string(Main,source,file)
inputdict=JSON3.read(read(joinpath(run,"input.json")),Dict{String,Any});inputdict["config"]["days"]=day
# Keep original spec identity. The experimental override is applied AFTER restore.
input=JSON3.read(JSON3.write(inputdict));first_sec[]=(day-1)*div(input.clock.day_us,1_000_000)
write(joinpath(out,"input.json"),JSON3.write(inputdict))
write(joinpath(out,"provenance.json"),JSON3.write((source_run=run,day=day,logging=enabled,
    checkpoint=checkpoint,checkpoint_sha256=bytes2hex(sha256(read(checkpoint))),
    source_code_hash=checkpoint_code_hash(),instrumentation_sha256=bytes2hex(sha256(codeunits(source))),
    override="Only relations[*].gradient_logging after original checkpoint identity/source validation; old records retained",
    warmup_seconds=512,threads=Threads.nthreads(),julia=string(VERSION))))
println("warmup $(ARGS[3]) day $day");flush(stdout)
try
    run_integrated(input;resume_from=checkpoint)
    error("warmup stop missing")
catch e
    e isa StopWarmup || rethrow()
end
warm[]=false;began[]=false;save_seconds[]=0.;GC.gc()
println("measured $(ARGS[3]) day $day");flush(stdout)
measured=@timed run_integrated(input;resume_from=checkpoint,checkpoint_dir=joinpath(out,"checkpoints"))
r,s=measured.value
metrics=Dict("day"=>day,"logging"=>enabled,"tick_and_daily_save_seconds"=>tick_seconds[],
    "checkpoint_save_seconds"=>save_seconds[],"call_seconds"=>measured.time,
    "allocated_bytes"=>measured.bytes,"gc_seconds"=>measured.gctime,"process_peak_rss_bytes"=>Sys.maxrss(),
    "new_gradient_records"=>Dict(a=>get(get(v,"gradient_maps",Dict()),"captured",0)-prior_captured[a] for (a,v) in s["social_relationships"]))
write(joinpath(out,"metrics.json"),JSON3.write(metrics))
# Earlier daily snapshots are already shared input, not new experimental output.
r["daily"]=r["daily"][end:end]
for (name,data) in (("result.json",r),("summary.json",s))
    open(joinpath(out,name),"w") do io;JSON3.write(io,data);end
end
println(JSON3.write(metrics));flush(stdout)
