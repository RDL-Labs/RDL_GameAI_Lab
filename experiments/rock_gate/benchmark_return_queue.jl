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
results=D()
# Optional pre-optimization method for checkpoints made by the optimized runtime.
# Only this trusted method is overridden in memory; checkpoint hashes remain checked.
length(ARGS)>=3 && include(abspath(ARGS[3]))
for variant in ("before","after")
    if variant=="after"
        include(joinpath(@__DIR__,"../../src/lw/learning/mb_return_outlook.jl"))
    end
    rows=Any[]
    for day in (1,3)
        println(variant," warm day ",day+1);flush(stdout);window(day)
        for repeat in 1:3
            GC.gc();r=window(day);push!(rows,r)
            println(variant," ",JSON3.write(r));flush(stdout)
        end
    end
    results[variant]=rows;write(joinpath(out,"comparison.json"),JSON3.write(results))
end
@testset "complete checkpoint-state equivalence" begin
    for day in (2,4)
        hashes=[x["state_sha256"] for rs in values(results) for x in rs if x["day"]==day]
        @test length(unique(hashes))==1
    end
end
