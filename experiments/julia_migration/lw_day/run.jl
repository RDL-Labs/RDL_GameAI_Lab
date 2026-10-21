# Compatibility entry; canonical implementation is in src or integrations.
using Test
include(joinpath(@__DIR__, "../../../src/lw/simulation/day.jl"))
if abspath(PROGRAM_FILE)==@__FILE__
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D(),"clock"=>input.clock)
@testset "LW day lifecycle" begin
    for spec in input.scenes
        elapsed=@elapsed r=lw_day(spec,input.clock)
        @test r["ended_us"]==17_280_000_000
        @test all(sum(values(r["counts"][a]))==17_280 for a in IDS)
        @test all(r["final_agents"][a]["sleep"]["sleep"]["cycle"]["status"]=="completed" for a in IDS)
        @test r["ground"]+r["consumed"]+sum(r["final_agents"][a]["inventory"]+r["final_agents"][a]["personal_stock"] for a in IDS)==r["initial_food"]
        @test all(isfinite(r["final_agents"][a]["body"]["reserve"]) for a in IDS)
        report["scenes"][spec.name]=D("elapsed_seconds_including_first_compilation"=>elapsed,"result"=>r)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
end
