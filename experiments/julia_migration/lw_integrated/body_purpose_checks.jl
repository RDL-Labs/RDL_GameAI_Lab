include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "body parent purpose" begin
    h=hunger_state("a");s=body_purpose_state("a");p=return_purpose()
    returning!(p,"return",0,false,0)
    hunger_update!(h,"a",0,90.)
    @test body_purpose!(s,h,90.,true,false,0,0).returning
    hunger_update!(h,"a",1_000_000,50.)
    @test !body_purpose!(s,h,50.,true,false,0,1_000_000).returning
    @test p["active"] && p["completed"]==0
    @test body_purpose!(s,h,50.,true,true,2,2_000_000).returning
    @test !body_purpose!(s,h,50.,true,true,0,3_000_000).returning
    hunger_update!(h,"a",6_000_000,90.)
    @test body_purpose!(s,h,90.,true,false,0,6_000_000).returning
    @test !s["replenishing"]
    @test p["active"] && p["entries"]==1
    @test_throws ErrorException body_purpose!(s,hunger_state("b"),50.,true,false,0,7_000_000)
end
@testset "night hunger interrupts return and acquires food" begin
    scene=merge(native_scene(42),(positions=[[-8.,0.],[0.,0.],[8.,0.]],home=[0.,-30.],
        food=[(x=x,z=.5,stock=30) for x in (-8.,0.,8.)],obstacles=NamedTuple[],
        initial_inventory=[0,0,0],reserve=[60.,60.,60.],hearing=false))
    clock=merge(native_clock(),(day_us=600_000_000,phase_boundaries_us=[1_000_000,2_000_000,3_000_000,600_000_000],quiet_night_us=4_000_000))
    off=lw_day(scene,clock;basic_loop=true,food_body=true,choice_seed=42)
    on=lw_day(scene,clock;basic_loop=true,food_body=true,body_purpose=true,choice_seed=42)
    @test on["consumed"]>off["consumed"]
    @test all(s["food_overrides"]>0 for s in values(on["body_purpose"]))
    @test any(any(e["replenishing"] && e["to"]=="food" for e in s["records"]) for s in values(on["body_purpose"]))
    @test any(any(!e["replenishing"] && e["to"]=="home" for e in s["records"]) for s in values(on["body_purpose"]))
    @test on["initial_food"]==on["ground"]+on["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(on["final_agents"]))
    @test all(sum(values(c))==600 for c in values(on["counts"]))
    println("diagnostic consumed off/on: ",off["consumed"]," / ",on["consumed"])
end
@testset "integrated body parent with existing LW features" begin
    input=JSON3.read(read(joinpath(@__DIR__,"search_review_spec.json"),String),Dict{String,Any})
    input["config"]["days"]=1
    input["config"]["body_purpose"]="on"
    input["config"]["general_landmarks"]="on"
    input["config"]["rho_profile"]="coarse"
    input["scene"]["reserve"]=[60.,60.,60.]
    input["clock"]["day_us"]=600_000_000
    input["clock"]["phase_boundaries_us"]=[1_000_000,2_000_000,3_000_000,600_000_000]
    input["clock"]["quiet_night_us"]=4_000_000
    r,summary=run_integrated(JSON3.read(JSON3.write(input)))
    @test r["body_purpose"]==summary["body_purpose"]
    @test all(s["decisions"]==600 for s in values(r["body_purpose"]))
    @test sum(s["food_overrides"] for s in values(r["body_purpose"]))>0
    @test all(r["daily"][1]["physical"][a]["loops"][f]["parent"]==a*":energy-maintenance" for a in IDS for f in ("food","home"))
    @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
    @test all(sum(values(c))==600 for c in values(r["counts"]))
end
