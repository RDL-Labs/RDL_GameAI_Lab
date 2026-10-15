include(joinpath(@__DIR__,"native.jl"))
using Test
spec,out=ARGS;mkpath(out)
input=JSON3.read(read(spec,String),Dict{String,Any})
input["config"]["days"]=1
for mode in ("off","on")
    input["config"]["parent_breadth"]=mode
    parsed=JSON3.read(JSON3.write(input))
    timed=@timed run_integrated(parsed)
    result,summary=timed.value
    summary["measurement"]=D("seconds"=>timed.time,"bytes"=>timed.bytes,"gc_seconds"=>timed.gctime)
    @test sum(a["operations"] for a in values(summary["agents"]))==51_840
    f=summary["food"];held=sum(a["stock"]+a["inventory"] for a in values(summary["agents"]))
    @test f["initial"]+f["added"]==f["ground"]+f["shared"]+f["consumed"]+held
    @test all(all(isfinite(a["body"][k]) for k in ("reserve","burst","strain","damage")) for a in values(summary["agents"]))
    if mode=="on"
        @test sum(s["restricted"] for s in values(summary["parent_breadth"]))>0
        @test all(s["admitted"]<=s["offered"] for s in values(summary["parent_breadth"]))
    else
        @test summary["parent_breadth"]===nothing
    end
    write(joinpath(out,"$mode-summary.json"),JSON3.write(summary))
    write(joinpath(out,"$mode-result.json"),JSON3.write(result))
    println(mode," complete: ",timed.time);flush(stdout)
end
