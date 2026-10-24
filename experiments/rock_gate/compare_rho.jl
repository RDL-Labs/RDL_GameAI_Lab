using JSON3, Test
root=normpath(joinpath(@__DIR__,"../.."))
inputs=Any[];rows=Any[]
@testset "fixed rho integration comparison" begin
    for profile in ("off","coarse","fine")
        dir=joinpath(root,"outputs/rock-gate-rho-$profile-20261023/narrow")
        spec=JSON3.read(read(joinpath(dir,"input.json"),String),Dict{String,Any})
        @test pop!(spec["config"],"rho_profile")==profile
        push!(inputs,spec)
        s=JSON3.read(read(joinpath(dir,"run/summary.json"),String))
        r=JSON3.read(read(joinpath(dir,"report.json"),String))
        events=[JSON3.read(line) for line in readlines(joinpath(dir,"crossings.jsonl"))]
        @test s.config.days==1
        for a in (:npc_a,:npc_b,:npc_c)
            stats=s.ground_effects[a]
            if profile=="off"
                @test !haskey(stats,:rho_applied)
            else
                @test stats.rho_profile==profile
                @test 0<stats.rho_applied<=stats.steering_attempts
                @test isfinite(stats.rho_last_potential.total)
            end
        end
        push!(rows,(profile=profile,measurement=s.measurement,food=r.food,
            actors=r.actors,ground_effects=Dict(a=>(attempts=s.ground_effects[a].steering_attempts,
                applied=get(s.ground_effects[a],:rho_applied,0)) for a in (:npc_a,:npc_b,:npc_c)),
            return_active_inward=count(e->e.direction=="in" && e.return_active,events)))
    end
    @test inputs[1]==inputs[2]==inputs[3]
end
dest=joinpath(@__DIR__,"evidence/rho_map");mkpath(dest)
write(joinpath(dest,"comparison.json"),JSON3.write(rows))
for row in rows
    println(row.profile," seconds=",round(row.measurement.call_seconds,digits=2),
        " consumed=",row.food.consumed," return-active crossings=",row.return_active_inward)
    for a in (:npc_a,:npc_b,:npc_c)
        v=row.actors[a]
        println("  ",a," out/in=",v.outward,"/",v.inward," reserve=",round(v.reserve,digits=2))
    end
end
