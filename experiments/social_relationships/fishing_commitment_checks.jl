using Test, Serialization
include("../../integrations/lightweight_julia/native.jl")
length(ARGS)==1 || error("usage: fishing_commitment_checks.jl D_START_FIXTURE")
f=deserialize(ARGS[1])
@testset "D selected fishing executes without another lottery" begin
    @test f.actor=="npc_d" && f.now==501712000000
    @test f.map["acquisition"]["choice"]["method"]=="fishing:23"
    @test f.target["distance"]<=1.25
    before_rng=copy(f.loop.rng)
    plan=fishing_plan!(f.foods,f.actor,f.loop,f.target,f.now)
    @test plan["action"]=="fish"
    @test plan["food_ref"]==23
    @test rand(copy(before_rng))==rand(copy(f.loop.rng))
    # Visibility loss does not invent an observation or discard the selected site.
    saved_choice=deepcopy(f.map["acquisition"]["choice"])
    @test isempty(acquisition_targets!(f.map,Any[],f.loop,f.now+2_000_000))
    @test f.map["acquisition"]["choice"]==saved_choice
    @test f.map["goal_arrival"]["food"]["target"]==23
    # The exact same physical location must support the actual work, not just a plan.
    f.world.bodies[f.actor],work,_,_=step(f.world.bodies[f.actor],"fish",f.world.inventory[f.actor])
    @test work=="worked"
    status=fishing_tick!(f.foods,f.world,f.cargo,f.food,f.stock,f.actor,24,f.now,"local:D:start")
    @test status=="fishing"
    @test fishing_state!(f.foods,f.actor)["active"]["ticks"]==1
    @test fishing_state!(f.foods,f.actor)["caught"]==0
    # Existing explicit interruption still terminates the fishing work.
    fishing_cancel!(f.foods,f.actor,f.now+1_000_000,"danger")
    @test fishing_state!(f.foods,f.actor)["active"]===nothing
    # A parent change clears an active acquisition trial and its selected source.
    acquisition_begin!(f.map,"fishing",23,saved_choice["seconds"])
    acquisition_finish!(f.map,"interrupted","parent_purpose_changed")
    @test f.map["acquisition"]["choice"]===nothing
    # Selecting exploration after interruption must not retain a stale arrival target.
    acquisition_targets!(f.map,Any[],f.loop,f.now+3_000_000)
    @test f.map["goal_arrival"]["food"]["target"]==f.map["acquisition"]["choice"]["ref"] || f.map["goal_arrival"]["food"]["target"]===nothing
end
@testset "new fishing choice uses its frozen forecast" begin
    fixture=deserialize(ARGS[1]);selected_map=nothing;selected_loop=nothing
    for skip in 0:31
        candidate_map=deepcopy(fixture.map);candidate_loop=deepcopy(fixture.loop)
        for _ in 1:skip;rand(candidate_loop.rng);end
        candidate_map["acquisition"]["choice"]=nothing
        candidate_map["acquisition"]["next_us"]=0
        acquisition_targets!(candidate_map,Any[fixture.target],candidate_loop,fixture.now)
        if candidate_map["acquisition"]["choice"]["technique"]=="fishing"
            selected_map=candidate_map;selected_loop=candidate_loop;break
        end
    end
    @test selected_map!==nothing
    if selected_map!==nothing
        acquisition=selected_map["acquisition"];choice=deepcopy(acquisition["choice"])
        deadline=acquisition["next_us"]
        @test deadline==fixture.now+ceil(Int,max(1.,choice["seconds"])*1_000_000)
        @test deadline>fixture.now+65_000_000
        @test isempty(acquisition_targets!(selected_map,Any[],selected_loop,fixture.now+65_000_000))
        @test acquisition["choice"]==choice
        @test acquisition["next_us"]==deadline # No sliding extension.
        old_records=length(acquisition["records"])
        acquisition_targets!(selected_map,Any[],selected_loop,deadline)
        @test acquisition["next_us"]>deadline
        @test last(acquisition["records"])["us"]==deadline
    end
end
