using BenchmarkTools, Statistics, Test
include(joinpath(@__DIR__,"../moving_social/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
function metrics(t)
    m=median(t)
    D("median_ns"=>m.time,"allocated_bytes"=>m.memory,"allocations"=>m.allocs,"times_ns"=>t.times)
end
specs=JSON3.read(read(ARGS[1],String));report=D("cases"=>D())
@testset "Compact execution boundaries" begin
    @test_throws ErrorException moving_scenario(specs[1];recording=:invalid)
    for spec in specs
        detailed=moving_scenario(spec;incremental=true)
        compact=moving_scenario(spec;incremental=true,recording=:compact)
        @test isempty(compact["rows"])
        @test sum(sum(values(c)) for c in values(compact["action_counts"]))==3*3*spec.ticks
        @test sum(compact["stock"])+sum(values(compact["inventory"]))+compact["consumed"]==60
        @test all(n[a]["sleep"]["cycle"]["status"]=="completed" for n in compact["nights"] for a in IDS)
        @test length(compact["transitions"])<length(detailed["rows"])
        # State and action agreement are diagnostics, not behavioral admission gates.
        keys_to_compare=("nights","request_counts","consumed","stock","inventory","final_agents")
        equal=all(plain(detailed[k])==plain(compact[k]) for k in keys_to_compare)
        expected=Dict(a=>Dict{String,Int}() for a in IDS)
        for r in detailed["rows"]
            c=expected[r["actor"]];a=r["plan"]["action"];c[a]=get(c,a,0)+1
        end
        before=plain(compact["nights"][1])
        compact["final_agents"]["npc_a"]["body"]["reserve"]=-999
        @test plain(compact["nights"][1])==before
        compact=moving_scenario(spec;incremental=true,recording=:compact)
        cases=D()
        for mode in (:detailed,:compact)
            value=mode==:detailed ? detailed : compact
            # Includes fresh World construction, all decisions, nights, recording and audits.
            t=@benchmark moving_scenario($spec;incremental=true,recording=$mode) samples=10 seconds=60 evals=1
            serialization=@benchmark JSON3.write($value) samples=10 seconds=30 evals=1
            cases[string(mode)]=D("execution"=>metrics(t),"serialization"=>metrics(serialization),
                "json_bytes"=>ncodeunits(JSON3.write(value)),"day_rows"=>length(value["rows"]),
                "transitions"=>length(get(value,"transitions",[])))
        end
        report["cases"][spec.name]=D("cost"=>cases,"terminal_equal_diagnostic"=>equal,
            "action_counts_equal_diagnostic"=>expected==compact["action_counts"],
            "action_counts"=>compact["action_counts"],"final_agents"=>compact["final_agents"],
            "requests"=>compact["request_counts"],"consumed"=>compact["consumed"])
    end
end
open(ARGS[2],"w") do io
    JSON3.write(io,report)
end
