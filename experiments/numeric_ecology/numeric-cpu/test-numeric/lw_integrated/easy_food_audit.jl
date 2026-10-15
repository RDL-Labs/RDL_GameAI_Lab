using JSON3, Test
out=ARGS[1]
@testset "easy food daily continuity and conservation" begin
for mode in ("off","on")
    r=JSON3.read(read(joinpath(out,"$mode-result.json"),String),Dict{String,Any})
    report=Any[];previous=Dict{String,Any}()
    for (day,d) in enumerate(r["daily"])
        held=sum(a["inventory"]+a["personal_stock"] for a in values(d["physical"]))
        @test r["initial_food"]+d["replenished_food"]==d["ground"]+d["shared_stock"]+d["consumed"]+held
        @test all(all(isfinite(a["body"][k]) for k in ("reserve","burst","strain","damage")) for a in values(d["physical"]))
        day>1 && (@test r["day_starts"][day]==r["daily"][day-1]["physical"])
        agents=Dict{String,Any}()
        for (a,p) in d["physical"]
            counts=d["counts"][a];old=get(previous,a,Dict{String,Any}())
            delta=Dict(k=>v-get(old,k,0) for (k,v) in counts)
            @test sum(values(delta))==17_280
            agents[a]=Dict("counts"=>delta,"reserve"=>p["body"]["reserve"],
                "inventory"=>p["inventory"],"position"=>p["position"],
                "sleep"=>d["sleep"][a]["sleep"]["cycle"]["status"])
        end
        push!(report,Dict("day"=>day,"agents"=>agents,"shared"=>d["shared_stock"]))
        previous=d["counts"]
    end
    write(joinpath(out,"$mode-daily-audit.json"),JSON3.write(report))
end
end
