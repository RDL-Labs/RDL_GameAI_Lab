using Test, Serialization, Random, JSON3
include("../../src/lw/LW.jl")

@testset "historical bonus contrasted with physical recovery" begin
    map=LW.mb_map_state("a");loop=LW.BasicLoop("home")
    for second in 0:59
        LW.configured_home_rest_step!(map,loop,true,"rest","performed",second*1_000_000,128_000_000)
    end
    @test map["configured_home_rest_reward"]["reward_total"]==5.
    body=LW.RDLBody.Body(10.,.8,90.,0.)
    rested,status,_,_=LW.step(body,"rest",0)
    @test status=="rested"
    @test rested.strain<body.strain
end

# These traps make accidental legacy calls fail, including allocation of state.
@eval LW begin
    inertia_state(actor)=error("retired inertia initialized")
    inertia_view(move,landmarks,hazard)=error("retired inertia observation")
    observe_inertia!(s,actor,now,view)=error("retired inertia update")
    record_continuation!(s,plan,loop,source)=error("retired inertia record")
    configured_home_rest_arrival!(s,loop,source,now)=error("retired rest arrival")
    configured_home_rest_step!(s,loop,at_home,action,status,now,day_us)=error("retired rest reward")
end

clock=merge(LW.native_clock(),(day_us=128_000_000,
    phase_boundaries_us=[0,0,128_000_000,128_000_000],quiet_night_us=128_000_000))
scene=merge(LW.native_scene(19),(positions=[[0.,0.],[.1,0.],[0.,.1]],home=[0.,0.],
    food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
    initial_inventory=[0,0,0],reserve=[95.,95.,95.]))
normalize(x)=JSON3.read(JSON3.write(x),Any)
@testset "retired flags cannot reactivate normal LW paths" begin
    mktempdir() do dir
        run(;kwargs...)=LW.lw_day(scene,clock;days=2,basic_loop=true,landmark_routes=true,
            mb_simulation=true,embedded_rest_enabled=true,choice_seed=33,kwargs...)
        result=run(configured_home_rest_enabled=true,movement_inertia=true,checkpoint_dir=joinpath(dir,"requested"))
        disabled=run(checkpoint_dir=joinpath(dir,"disabled"))
        @test result["movement_inertia"]===nothing
        @test result["retired_action_paths"]["home_rest_reward"]==LW.D("requested"=>true,"effective"=>false)
        @test result["retired_action_paths"]["movement_inertia"]==LW.D("requested"=>true,"effective"=>false)
        for a in LW.IDS
            @test result["counts"][a]["rest"]>=60
            @test !haskey(result["mb_map"][a],"configured_home_rest_reward")
            @test result["mb_map"][a]["embedded_rest"]["decisions"]>0
        end
        for key in ("events","counts","final_agents","daily","mb_map","home_activity")
            @test normalize(result[key])==normalize(disabled[key])
        end
        onstate=deserialize(joinpath(dir,"requested/day-002.jls")).state
        offstate=deserialize(joinpath(dir,"disabled/day-002.jls")).state
        @test onstate[:inertia]===nothing && offstate[:inertia]===nothing
        for a in LW.IDS, family in keys(onstate[:loops][a])
            @test rand(deepcopy(onstate[:loops][a][family].rng),UInt64,8)==rand(deepcopy(offstate[:loops][a][family].rng),UInt64,8)
        end
        resumed=run(configured_home_rest_enabled=true,movement_inertia=true,
            resume_from=joinpath(dir,"requested/day-001.jls"))
        for key in ("events","counts","final_agents","daily","mb_map","home_activity")
            @test normalize(result[key])==normalize(resumed[key])
        end
    end
end
