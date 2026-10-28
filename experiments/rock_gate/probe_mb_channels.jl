using JSON3, Test, Serialization, SHA
const run=abspath(ARGS[1]);const out=abspath(ARGS[2]);mkpath(out)
const snapshot=joinpath(run,"source");const stop_sec=Ref(0);const start_sec=Ref(0)
const started=Ref(0.);const startbytes=Ref{Int64}(0);const elapsed=Ref(0.);const allocated=Ref(0);const digest=Ref("")
struct Finished <: Exception end
function gate_probe!(sec,w,purposes,counts,home)
    if sec==start_sec[];started[]=time();Base.gc_bytes(startbytes);end
end
function finish!(state)
    elapsed[]=time()-started[];b=Ref{Int64}(0);Base.gc_bytes(b);allocated[]=b[]-startbytes[]
    io=IOBuffer();serialize(io,state);digest[]=bytes2hex(sha256(take!(io)))
    throw(Finished())
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
# Optional shared overrides, applied to both variants (prior optimizations).
foreach(p->include(abspath(p)),ARGS[5:end])
const file=joinpath(snapshot,"src/lw/simulation/day.jl")
text=replace(read(file,String),r"(?m)^include.*\r?\n"=>"");anchor="        Main.gate_probe!(sec,w,purposes,counts,spec.home)"
@assert count(anchor,text)==1
# Test-only in-memory hook. Original files/hash and checkpoint validation remain intact.
Base.include_string(Main,replace(text,anchor=>"        sec==Main.stop_sec[] && Main.finish!(@lw_capture)\n"*anchor),file)
const input=JSON3.read(read(joinpath(run,"ordinary/input.json"),String))
function window(day)
    start_sec[]=day*17280+60;stop_sec[]=start_sec[]+512
    try
        run_integrated(input;resume_from=joinpath(run,"ordinary/checkpoints/day-"*lpad(day,3,'0')*".jls"))
        error("missing bounded stop")
    catch e
        e isa Finished || rethrow()
    end
    D("day"=>day+1,"seconds"=>elapsed[],"bytes"=>allocated[],"state_sha256"=>digest[])
end
for f in ("learning/mb_recognition.jl","learning/mb_chunks.jl","learning/mb_routes.jl","learning/mb_map.jl","learning/mb_sleep.jl","decision/relation_field.jl")
 include(joinpath(@__DIR__,"../../src/lw",f))
end
const proposal_counts=Dict("all"=>0,"intermediate"=>0)
chunk_source=read(joinpath(@__DIR__,"../../src/lw/learning/mb_chunks.jl"),String)
Base.include_string(Main,replace(chunk_source,"function mb_chunk_candidates!("=>"function original_channel_candidates!("))
function mb_chunk_candidates!(s,args...;kwargs...)
 result=original_channel_candidates!(s,args...;kwargs...)
 for p in result
  path=p["mb_path"]
  @assert s["edges"][first(path)]["from"]==p["mb_recognized"]
  @assert all(s["edges"][path[i]]["to"]==s["edges"][path[i+1]]["from"] for i in 1:length(path)-1)
  @assert p["mb_route_index"]==1
  proposal_counts["all"]+=1
  proposal_counts["intermediate"]+=Int(p["mb_chunk_index"]>1)
 end
 result
end
rows=Any[]
for day in (1,89)
 push!(rows,window(day));println(JSON3.write(last(rows)));flush(stdout)
end
write(joinpath(out,"summary.json"),JSON3.write(D("windows"=>rows,"proposals"=>proposal_counts)))
