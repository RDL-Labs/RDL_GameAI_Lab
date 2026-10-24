using Sockets, JSON3, SHA, Statistics
const out=abspath(ARGS[1])
const root=normpath(joinpath(@__DIR__,"../.."))
const source=joinpath(out,"src")
cp(joinpath(root,"src"),source)
path=joinpath(source,"lw/simulation/day.jl")
original=read(path,String)
begin_anchor="        now=sec*1_000_000;w.seconds=sec"
end_anchor="    ground_wear && advance_wear!(wear,wear_offset+Int(days*clock.day_us))"
@assert count(begin_anchor,original)==1 && count(end_anchor,original)==1
# Only observer/pacing hooks in an isolated source copy. All behavior remains unchanged.
patched=replace(original,begin_anchor=>"        Main.tick_begin!(sec)\n"*begin_anchor)
tail="        end\n    end\n"*end_anchor
@assert count(tail,patched)==1
patched=replace(patched,tail=>"        end\n        Main.tick_end!(sec,w,stock,shared,counts,plans)\n    end\n"*end_anchor)
write(path,patched)
module ExperimentLW
include(joinpath(Main.source,"lw/simulation/integrated.jl"))
end
const mode=Ref(:baseline)
const started=Ref(UInt64(0))
const permits=Channel{Int}(0)
const replies=Channel{Any}(0)
const baseline=String[]
const base_times=Float64[]
const live_times=Float64[]
const specbytes=read(joinpath(root,"experiments/julia_migration/lw_integrated/search_review_spec.json"),String)
specdict=JSON3.read(specbytes,Dict{String,Any});specdict["config"]["days"]=1
const input=JSON3.read(JSON3.write(specdict))
write(joinpath(out,"spec.json"),JSON3.write(specdict))
write(joinpath(out,"manifest.json"),JSON3.write((julia=string(VERSION),
    spec_sha256=bytes2hex(sha256(JSON3.write(specdict))),
    source_day_sha256=bytes2hex(sha256(original)),instrumented_day_sha256=bytes2hex(sha256(patched)),
    scope="LW authoritative World; Luanti tick pacing only; one outstanding batch of three agents")))
function tick_begin!(sec)
    if mode[]==:live
        @assert take!(permits)==sec+1
    end
    started[]=time_ns()
end
function tick_end!(sec,w,stock,shared,counts,plans)
    elapsed=(time_ns()-started[])/1e6
    snapshot=JSON3.write((positions=w.positions,bodies=Dict(a=>ExperimentLW.bodydict(w.bodies[a]) for a in ExperimentLW.IDS),
        inventory=w.inventory,stock=stock,shared=shared,consumed=w.consumed,counts=counts,plans=plans))
    hash=bytes2hex(sha256(snapshot))
    if mode[]==:baseline
        push!(baseline,hash);push!(base_times,elapsed)
    else
        @assert hash==baseline[sec+1] "LW tick differs from standalone"
        push!(live_times,elapsed)
        if mod(sec+1,2000)==0
            println("LIVE ticks=$(sec+1)");flush(stdout)
        end
        put!(replies,(seq=sec+1,compute_ms=elapsed,matched=true,positions=w.positions))
    end
end
println("BASELINE");flush(stdout)
reference=ExperimentLW.run_integrated(input)
write(joinpath(out,"baseline-summary.json"),JSON3.write(reference[2]))
write(joinpath(out,"baseline-ticks.json"),JSON3.write((hashes=baseline,compute_ms=base_times)))
mode[]=:live
const worker=@async begin
    try
        result=ExperimentLW.run_integrated(input)
        @assert isequal(result,reference) "Final full LW result differs"
        write(joinpath(out,"parity.json"),JSON3.write((ticks=length(live_times),full_result_equal=true,baseline_ms=base_times,live_ms=live_times)))
        put!(replies,(complete=true,ticks=length(live_times),full_result_equal=true))
    catch e
        showerror(stderr,e,catch_backtrace());println(stderr);flush(stderr)
        put!(replies,(error=sprint(showerror,e),))
    end
end
listener=listen(ip"127.0.0.1",18765)
println("READY ticks=$(length(baseline))");flush(stdout)
for seq in 1:length(baseline)+1
    sock=accept(listener)
    try
        request=readline(sock);len=0
        while true
            line=strip(readline(sock));isempty(line) && break
            startswith(lowercase(line),"content-length:") && (len=parse(Int,strip(split(line,':';limit=2)[2])))
        end
        @assert 0<len<=4096
        req=JSON3.read(String(read(sock,len)));@assert Int(req.seq)==seq
        seq<=length(baseline) && put!(permits,seq)
        response=take!(replies)
        payload=JSON3.write(response)
        write(sock,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: $(sizeof(payload))\r\nConnection: close\r\n\r\n",payload);flush(sock)
        hasproperty(response,:error) && error(response.error)
    finally
        close(sock)
    end
end
close(listener)
println("COMPLETE full_result_equal=true");flush(stdout)
