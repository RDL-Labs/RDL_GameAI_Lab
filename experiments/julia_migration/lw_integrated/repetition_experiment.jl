include(joinpath(@__DIR__,"native.jl"))
using Test
spec,out=ARGS;mkpath(out)
input=JSON3.read(read(spec,String),Dict{String,Any})
input["config"]["days"]=1;input["config"]["parent_breadth"]="on"
for mode in ("off","on")
    input["config"]["repetition_pressure"]=mode
    write(joinpath(out,"$mode-spec.json"),JSON3.write(input))
    timed=@timed run_integrated(JSON3.read(JSON3.write(input)))
    result,summary=timed.value
    f=summary["food"];held=sum(a["stock"]+a["inventory"] for a in values(summary["agents"]))
    @test f["initial"]+f["added"]==f["ground"]+f["shared"]+f["consumed"]+held
    @test sum(a["operations"] for a in values(summary["agents"]))==51_840
    if mode=="on"
        @test sum(s["additions"] for s in values(summary["repetition_pressure"]))>0
        @test sum(s["changes"] for s in values(summary["repetition_pressure"]))>0
        @test all(length(s["nodes"])<=64 for s in values(summary["repetition_pressure"]))
    end
    summary["measurement"]=D("seconds"=>timed.time,"bytes"=>timed.bytes)
    write(joinpath(out,"$mode-summary.json"),JSON3.write(summary))
    write(joinpath(out,"$mode-result.json"),JSON3.write(result))
    println(mode," complete ",timed.time);flush(stdout)
end
