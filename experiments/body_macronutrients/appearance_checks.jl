using Test, Serialization
include("../../src/lw/LW.jl")
@testset "composition becomes bounded public appearance" begin
    world=LW.world(false);empty!(world.obstacles)
    world.positions["npc_a"]=(0.,0.);world.positions["npc_b"]=(0.,1.)
    world.positions["npc_c"]=(100.,100.)
    gut=LW.Digestion(macronutrients=true)
    human=LW.HumanBody(gut.macro_body.body,gut.macro_body.hours_per_second)
    world.bodies["npc_b"]=human
    observed(;yaw=0.,rho="coarse",attention=nothing)=LW.social_sight(world,"npc_a",yaw,0;rho,attention,illumination=1.)
    healthy=LW.configured_body_appearance(human)
    @test healthy==(roundness=.5,build=1.,weakness=0.)
    human.nutrients.fat=50.;human.nutrients.tissue=85.
    thin=LW.configured_body_appearance(human)
    @test thin.roundness<healthy.roundness && thin.build<healthy.build
    @test thin.weakness≈.3
    fine=only(observed(rho="fine",attention="npc_b")["peers"])
    coarse=only(observed()["peers"])
    @test fine["body_appearance"].roundness==.125
    @test coarse["body_appearance"].roundness==0.
    @test only(observed(rho="fine")["peers"])["body_appearance"]==coarse["body_appearance"]
    @test Set(keys(fine["body_appearance"]))==Set((:roundness,:build,:weakness))
    @test !any(haskey(fine,k) for k in ("body","fat","tissue","sugar","alive","reserve"))
    # Gut fullness can suppress demand, but cannot instantly repair visible tissue.
    human.nutrients.gut=(120.,0.,0.)
    @test LW.configured_expression(human).distress>=thin.weakness
    @test LW.configured_body_appearance(human)==thin
    world.positions["npc_b"]=(0.,6.)
    distant=only(observed(rho="fine",attention="npc_b")["peers"])["body_appearance"]
    @test all(x->x in (0.,1.),values(distant))
    @test isempty(observed(yaw=180.)["peers"])
    push!(world.obstacles,LW.RDLMigrationProbe.Circle(0.,3.,.5))
    @test isempty(observed()["peers"])
    empty!(world.obstacles)
    # Inspection does not alter physiology; observations are snapshots, not references.
    saved=deepcopy(human.nutrients)
    observed()
    @test all(getfield(saved,k)==getfield(human.nutrients,k) for k in fieldnames(typeof(saved)))
    human.nutrients.fat=200.;human.nutrients.tissue=100.
    @test fine["body_appearance"].roundness==.125
    @test LW.configured_body_appearance(human)==healthy
    io=IOBuffer();serialize(io,fine);seekstart(io)
    @test deserialize(io)==fine
    @test LW.configured_body_appearance(LW.Body(10.,0.,90.,0.))===nothing
end
