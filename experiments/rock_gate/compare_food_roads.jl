using JSON3, Test
root=normpath(joinpath(@__DIR__,"../.."))
rows=Any[];inputs=Any[]
@testset "same food layout, external roads only" begin
    for mode in ("off","on")
        dir=joinpath(root,"outputs/food-roads-$mode-20261025/narrow")
        input=JSON3.read(read(joinpath(dir,"input.json"),String),Dict{String,Any})
        roads=pop!(input["scene"],"artificial_roads");push!(inputs,input)
        @test length(roads)==(mode=="on" ? 2 : 1)
        r=JSON3.read(read(joinpath(dir,"run/result.json"),String))
        s=JSON3.read(read(joinpath(dir,"run/summary.json"),String))
        report=JSON3.read(read(joinpath(dir,"report.json"),String))
        crossings=[JSON3.read(l) for l in readlines(joinpath(dir,"crossings.jsonl"))]
        @test length(r.world_checkpoint.stock)==3
        @test all(0<=n<=24 for n in r.world_checkpoint.stock)
        @test r.initial_food==76 # 72 at sites, four initially carried
        push!(rows,(mode=mode,seconds=s.measurement.call_seconds,
            harvested_by_site=24 .- r.world_checkpoint.stock,consumed=r.consumed,
            actors=Dict(a=>(outward=report.actors[a].outward,inward=report.actors[a].inward,
                return_completed=report.actors[a].return_purpose.completed,
                ground_selections=r.ground_continuity[a].selections,
                reserve=report.actors[a].reserve) for a in (:npc_a,:npc_b,:npc_c)),
            return_active_inward=count(e->e.direction=="in" && e.return_active,crossings)))
    end
    @test inputs[1]==inputs[2]
end
dest=joinpath(@__DIR__,"evidence/food_roads");mkpath(dest)
write(joinpath(dest,"comparison.json"),JSON3.write(rows))
for r in rows;println(JSON3.write(r));end
