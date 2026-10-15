include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
@testset "Renewal accounting boundaries" begin
    food=[(stock=12,),(stock=6,)];stock=[0,4]
    @test replenish_food!(stock,food)==14
    @test stock==[12,6]
    @test replenish_food!(stock,food)==0
    stock[1]=13
    @test replenish_food!(stock,food)==0 && stock==[13,6]
end
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Renewable four-day living" begin
    for spec in input.scenes
        modes=D()
        for enabled in (false,true)
            r=lw_day(spec,input.clock;days=4,basic_loop=true,landmark_routes=true,harvest_sleep=true,
                model_field=true,model_review=true,model_relearn=enabled,renewable_food=true)
            @test all(sum(values(r["counts"][a]))==4*17_280 for a in IDS)
            @test all(plain(r["day_starts"][d])==plain(r["daily"][d-1]["physical"]) for d in 2:4)
            @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in r["daily"] for a in IDS)
            @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==r["initial_food"]+n["replenished_food"] for n in r["daily"])
            @test length(r["replenishments"])==3
            @test sum(x["added"] for x in r["replenishments"])==r["replenished_food"]
            for a in IDS
                h=r["final_agents"][a]["harvest"]
                if get(h,"replacement_used",false)
                    old=vcat(h["previous_model"]["formation"],h["previous_model"]["validation"],[first(h["invalidations"])["operation"]])
                    new=vcat(h["model"]["formation"],h["model"]["validation"])
                    @test isempty(intersect(old,new))
                    @test h["model"]["prediction"]==D("acquired"=>1)
                end
            end
            modes[enabled ? "enabled" : "disabled"]=r
        end
        # Both start before any invalidation/replacement, so first-day actions match.
        @test [e for e in modes["enabled"]["events"] if e["us"]<input.clock.day_us]==[e for e in modes["disabled"]["events"] if e["us"]<input.clock.day_us]
        report["scenes"][spec.name]=modes
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
