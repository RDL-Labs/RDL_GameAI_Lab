using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
@testset "empty world cannot complete provision goal or enable idle" begin
    input=JSON3.read(read(joinpath(@__DIR__,"navigation_idle_10d_input.json"),String),Dict{String,Any})
    s=input["scene"];c=input["config"]
    merge!(c,D("days"=>1,"home_observation"=>"off","night_fear"=>"off"))
    c["mb_sensitivities"]=D(a=>c["mb_sensitivities"][a] for a in IDS)
    s["experimental_actor_ids"]=collect(IDS)
    for k in ("positions","reserve","initial_inventory","initial_inventory_kinds","initial_personal_stock")
        s[k]=s[k][1:length(IDS)]
    end
    s["initial_personal_food_counts"]=D(a=>s["initial_personal_food_counts"][a] for a in IDS)
    s["configured_camp_landmark"]=false;s["configured_camp_experience"]=false
    s["initial_inventory"]=fill(0,length(IDS));s["initial_inventory_kinds"]=[Int[] for _ in IDS]
    for f in s["food"];f["stock"]=0;end
    merge!(input["clock"],D("day_us"=>1200_000_000,"phase_boundaries_us"=>[1_000_000,900_000_000,1000_000_000,1200_000_000],"quiet_night_us"=>1100_000_000))
    println("CONDITIONS: 3 actors, 1200 ticks, empty food sites, personal stock 60, no initial cargo; fixed pause ON, initial observation OFF. Verify local return does not end parent goal.")
    r,_=run_integrated(JSON3.read(JSON3.write(input)))
    @test sum(length(m["daily_plan"]["local_returns"]) for m in values(r["mb_map"]))>0
    for a in IDS
        m=r["mb_map"][a];p=m["daily_plan"]
        @test !p["active"]["closed"]
        @test isempty(p["records"])
        @test p["active"]["started_us"]==0
        @test p["active"]["deadline_us"]==1200_000_000
        @test m["configured_post_return_idle"]["ticks"]==0
        @test m["observations"]==1200
        @test sum(values(r["counts"][a]))==1200
        @test all(x->!x["completed"],get(p["models"],"roundtrip:unknown_food",Any[]))
    end
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(f["inventory"]+f["personal_stock"] for f in values(r["final_agents"]))
    println("LOCAL_RETURNS ",JSON3.write(D(a=>length(r["mb_map"][a]["daily_plan"]["local_returns"]) for a in IDS)))
end
