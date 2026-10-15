using BenchmarkTools,Statistics,Test
include(joinpath(@__DIR__,"../moving_social/run.jl"))
plain(x)=JSON3.read(JSON3.write(x),Dict{String,Any})
function record(i,target="b",outcome="refuse",actor="a")
    D("agent_id"=>actor,"target"=>target,"outcome"=>outcome,
      "request_observation_id"=>"request:$i","source_observation_id"=>"result:$i")
end
function prepare(n)
    records=Records();live=live_aid("a")
    for i in 1:n
        records[string(i)]=record(i,isodd(i) ? "b" : "c",i%7==0 ? "request_not_executed" : i%3==0 ? "given" : "refuse")
        pressure_poll!(live,records,i-1)
    end
    old=pressure_update(nothing,records,"a",3);added=deepcopy(records)
    added[string(n+1)]=record(n+1)
    live,old,records,added
end
function poll_snapshot!(live,records,n)
    pressure_poll!(live,records,n);pressure_snapshot(live)
end
report=D("status"=>"candidate","diagnostics"=>D(),"cases"=>D(),"integration"=>D())
@testset "Mutable aid behavioral boundaries" begin
    for failing in ("b","c")
        live=live_aid("a");other=failing=="b" ? "c" : "b"
        untouched=live_aid("other");before=plain(untouched.state)
        snap=pressure_snapshot(live);snap_before=plain(snap)
        for i in 1:4
            pressure_update!(live,aid_notice(string(i),record(i,failing)))
        end
        @test live.state.methods[failing].H>0
        @test select_target(["b","c"],D(),live.state)[1]==other
        @test plain(snap)==snap_before
        @test plain(untouched.state)==before
        @test select_target(String[],D(),live.state)[1]===nothing
        current=plain(live.state)
        @test pressure_update!(live)===live.state
        @test plain(live.state)==current
        pressure_update!(live,aid_notice("4",record(4,failing)))
        @test plain(live.state)==current
        @test_throws ErrorException pressure_update!(live,aid_notice("4",record(4,failing,"given")))
        @test_throws ErrorException pressure_update!(live,aid_notice("x",record(1,failing,"given","other")))
        @test plain(live.state)==current
        pressure_update!(live,aid_notice("5",record(5,failing,"given")))
        @test live.state.methods[failing].H==0
        snap=pressure_snapshot(live);saved=plain(snap)
        live.state.methods[failing].H+=1
        @test plain(snap)==saved
        snap.parent.H+=999
        @test live.state.parent.H!=snap.parent.H
    end
    live=live_aid("a")
    pressure_update!(live,aid_notice("1",record(1,"b","request_not_executed")))
    @test live.state.parent.H==0
    pressure_update!(live,aid_notice("2",record(2,"b","no_response_observed")))
    @test live.state.parent.H>0
    @test live.state.parent.records["1"]["status"]=="defer"
end

specs=JSON3.read(read(ARGS[1],String))
@testset "Representative moving contact" begin
    b=contact_boundaries(specs[1])
    @test b["near"] && !b["far"] && !b["occluded"]
    @test b["old_response"]["status"]=="unavailable"
    @test b["new_response"]["status"]=="transferred"
    for spec in specs
        old=moving_scenario(spec);new=moving_scenario(spec;incremental=true)
        # Equality is diagnostic, not an admission gate.
        equal=plain(old)==plain(new)
        @test sum(new["stock"])+sum(values(new["inventory"]))+new["consumed"]==60
        @test all(n[a]["sleep"]["cycle"]["status"]=="completed" for n in new["nights"] for a in IDS)
        @test all(r["plan"]["action"]!="request" || r["plan"]["target"] in [o["ref"] for o in r["observation"]["others"] if o["holding_food"]] for r in new["rows"])
        report["integration"][spec.name]=D("old_trace_equal_diagnostic"=>equal,"consumed"=>new["consumed"],
            "requests"=>new["request_counts"],"final_agents"=>new["final_agents"])
    end
end

for n in (3,16,64)
    live,old,records,added=prepare(n)
    report["diagnostics"][string(n)]=plain(live.state)==plain(old)
    result=D()
    for (label,input) in (("zero_new",records),("one_new",added))
        pressure_update(old,input,"a",3);pressure_poll!(deepcopy(live),input,n);poll_snapshot!(deepcopy(live),input,n)
        trials=D()
        trials["old"]=@benchmark pressure_update($old,$input,"a",3) samples=30 seconds=2 evals=1
        trials["incremental"]=@benchmark pressure_poll!(l,$input,$n) setup=(l=deepcopy($live)) samples=30 seconds=2 evals=1
        trials["incremental_snapshot"]=@benchmark poll_snapshot!(l,$input,$n) setup=(l=deepcopy($live)) samples=30 seconds=2 evals=1
        result[label]=D()
        for (name,t) in trials
            m=median(t);result[label][name]=D("median_ns"=>m.time,"allocated_bytes"=>m.memory,"allocations"=>m.allocs,"samples"=>length(t),"times_ns"=>t.times)
        end
    end
    snapshot_trial=@benchmark pressure_snapshot($live) samples=30 seconds=2 evals=1
    m=median(snapshot_trial);result["snapshot_only"]=D("median_ns"=>m.time,"allocated_bytes"=>m.memory)
    report["cases"][string(n)]=result
end
open(ARGS[2],"w") do io
    JSON3.write(io,report)
end
println(JSON3.write(report))
