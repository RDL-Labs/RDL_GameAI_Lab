using Test
include("../src/lw/LW.jl")

struct WaitMovementPolicy end
LW.evaluate_movement(::WaitMovementPolicy,o)=(action=:wait,observed_food=length(o.visible))

@testset "LW perception and decision boundary" begin
    scene=LW.native_scene(20261005)
    w=LW.moving_world(scene)
    yaw=Dict(a=>0. for a in LW.IDS)
    stock=Int[f.stock for f in scene.food]
    observation=LW.perceive_movement(w,"npc_a",yaw,scene.food,stock;running=true)
    result=LW.evaluate_movement(LW.EnergyMovementPolicy(),observation)
    @test length(result["energy"]["rows"])==5
    @test length(result["run_rows"])==5
    @test result==LW.movement_observation(w,"npc_a",yaw,scene.food,stock;running=true)
    alternative=LW.movement_observation(w,"npc_a",yaw,scene.food,stock;policy=WaitMovementPolicy())
    @test alternative.action==:wait
    # The observation remains usable after its source world changes.
    w.bodies["npc_a"]=LW.Body(0.,1.,0.,0.)
    w.positions["npc_a"]=(999.,999.)
    empty!(w.inventory)
    @test LW.evaluate_movement(LW.EnergyMovementPolicy(),observation)==result
end
