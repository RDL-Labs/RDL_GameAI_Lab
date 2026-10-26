function mixed_transfer_population!(input)
    s=input["scene"];hx,hz=Float64.(s["home"])
    positions=[[hx+x,hz+z] for x in (-2.,0.,2.) for z in (1.5,2.5)]
    s["positions"]=positions;s["reserve"]=fill(90.,6);s["initial_inventory"]=zeros(Int,6)
    haskey(s,"initial_personal_stock") && (s["initial_personal_stock"]=zeros(Int,6))
    s["actor_ids"]=collect(IDS)
    profiles=input["config"]["mb_sensitivities"]
    for (old,new) in (("npc_a","npc_d"),("npc_b","npc_e"),("npc_c","npc_f"))
        profiles[new]=deepcopy(profiles[old])
    end
    s["cohorts"]=D("experienced"=>["npc_a","npc_b","npc_c"],"naive"=>["npc_d","npc_e","npc_f"],
        "matched_pairs"=>[["npc_a","npc_d"],["npc_b","npc_e"],["npc_c","npc_f"]])
    obstacles=vcat(s["obstacles"],get(s,"low_obstacles",Any[]))
    @testset "mixed transfer population" begin
        @test length(IDS)==length(positions)==6
        @test Set(keys(s["learned_mb_transfer"]["maps"]))==Set(s["cohorts"]["experienced"])
        @test all(p->all(o->hypot(p[1]-o["x"],p[2]-o["z"])>o["radius"]+.2,obstacles),positions)
        @test all(hypot(positions[i][1]-positions[j][1],positions[i][2]-positions[j][2])>.4 for i in 1:6 for j in i+1:6)
        @test all(profiles[a]==profiles[b] for (a,b) in s["cohorts"]["matched_pairs"])
    end
end
