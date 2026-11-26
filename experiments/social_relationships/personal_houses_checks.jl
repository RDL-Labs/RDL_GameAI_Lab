using Test, Serialization, Random
include("../../integrations/lightweight_julia/native.jl")

@testset "personal houses: scalable world geometry" begin
    scene=native_landscape_scene(20261007)
    owners=["resident_$i" for i in 1:100]
    houses=personal_houses(scene,owners)
    @test length(houses)==100
    @test personal_houses(scene,owners[1:4])==houses[1:4]
    @test personal_houses(scene,owners[1:10])==houses[1:10]
    @test [h.storage_owner for h in houses]==owners
    @test length(unique(h.id for h in houses))==100
    @test all(h->landscape_material(scene.landscape,(h.x,h.z))!="water",houses)
    @test all(h->all(o->hypot(h.x-o.x,h.z-o.z)>=h.radius+o.radius,scene.obstacles),houses)
    @test all(hypot(a.x-b.x,a.z-b.z)>=a.radius+b.radius for a in houses for b in houses if a.id!=b.id)
    @test personal_house_presence(houses,owners[1],houses[1].rest_position).inside
    @test !personal_house_presence(houses,owners[1],scene.home).inside
    @test personal_house_presence(houses,"unknown",scene.home)===nothing
    @test isempty(personal_houses(merge(scene,(personal_houses=false,)),owners))
    @test_throws ErrorException personal_houses(scene,["same","same"])
    @test_throws ErrorException personal_houses(merge(scene,(personal_house_settings=(max_rings=1,),)),owners)
    Random.seed!(92);expected=rand();Random.seed!(92)
    personal_houses(scene,owners)
    @test rand()==expected
    io=IOBuffer();serialize(io,houses);seekstart(io)
    @test deserialize(io)==houses
end

@testset "LW connection and restore" begin
    scene=native_scene(9)
    clock=merge(native_clock(),(day_us=16_000_000,
        phase_boundaries_us=[0,0,16_000_000,16_000_000],quiet_night_us=16_000_000))
    mktempdir() do checkpoints
        first=lw_day(scene,clock;days=1,checkpoint_dir=checkpoints)
        restored=lw_day(scene,clock;days=2,resume_from=joinpath(checkpoints,"day-001.jls"))
        full=lw_day(scene,clock;days=2)
        @test first["world_checkpoint"]["personal_houses"]==personal_houses(scene,IDS)
        @test restored["world_checkpoint"]["personal_houses"]==full["world_checkpoint"]["personal_houses"]
        @test restored["final_agents"]==full["final_agents"]
        @test restored["counts"]==full["counts"]
    end
end
