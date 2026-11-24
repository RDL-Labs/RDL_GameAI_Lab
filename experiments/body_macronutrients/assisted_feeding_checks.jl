using Test, Serialization
include("../../src/lw/LW.jl")
const RB=LW.RDLBody
@testset "selected aid feeds an incapacitated human once" begin
    w=LW.world(true);empty!(w.obstacles)
    donor,receiver=LW.IDS[1:2]
    w.positions[donor]=(0.,0.);w.positions[receiver]=(0.,.5)
    for a in LW.IDS;w.inventory[a]=0;end
    guts=Dict(a=>LW.Digestion(macronutrients=true) for a in LW.IDS)
    for a in LW.IDS;w.bodies[a]=LW.HumanBody(guts[a].macro_body.body,guts[a].macro_body.hours_per_second);end
    n=w.bodies[receiver].nutrients
    n.sugar=0.;n.fat=0.;n.amino=0.;n.tissue=RB.MACRO_PARAMETERS.tissue_minimum
    guts[receiver].macro_body.initial_energy=RB.Macronutrients.nutrient_energy(n)
    scene=merge(LW.native_scene(19),(typed_food=true,))
    foods=LW.food_resources(scene,w,Any[],Int[],0,Dict(a=>0 for a in LW.IDS))
    cargo=Dict(a=>Int[] for a in LW.IDS)
    @test LW.configured_collapse_active(w.bodies[receiver]) && LW.body_alive(w.bodies[receiver])
    consumed_before=w.consumed
    for (i,kind) in enumerate((RB.FRUIT_FOOD,RB.FRUIT_FOOD,RB.COOKED_FISH))
        w.inventory[donor]+=1;push!(cargo[donor],i);LW.food_push!(foods,donor,kind)
        op="rescue:$i"
        receipt=LW.communicate!(w,donor,op,"give",receiver;food_kind=kind,unsolicited=true)
        @test receipt["status"]=="transferred"
        push!(cargo[receiver],popfirst!(cargo[donor]));LW.food_give!(foods,donor,receiver)
        @test LW.configured_assisted_feeding!(w,foods,guts,cargo,donor,receiver,op,kind,i;enabled=false)===nothing
        record=LW.configured_assisted_feeding!(w,foods,guts,cargo,donor,receiver,op,kind,i)
        @test record["status"]=="assisted_fed"
        @test LW.configured_assisted_feeding!(w,foods,guts,cargo,donor,receiver,op,kind,i)===nothing
        @test w.inventory[receiver]==0 && isempty(cargo[receiver]) && isempty(foods.inventory[receiver])
        @test n.sugar==0 && n.tissue==RB.MACRO_PARAMETERS.tissue_minimum
    end
    @test w.consumed-consumed_before==3 && guts[receiver].eaten==3
    @test sum(foods.consumed)==3
    io=IOBuffer();serialize(io,(w,guts));seekstart(io);rw,rg=deserialize(io)
    @test rw.bodies[receiver].nutrients===rg[receiver].macro_body.body
    for tick in 1:360
        LW.advance_physiology!(rw,Dict(a=>0. for a in LW.IDS),rg,true)
    end
    @test !LW.configured_collapse_active(rw.bodies[receiver])
    @test LW.body_alive(rw.bodies[receiver])
    @test abs(LW.digestion_snapshot(rg[receiver])["energy_residual"])<1e-6
    # Default standalone/other-species policy remains fatal, old dead saves do
    # not revive merely because the human parameter has changed.
    dead=RB.Macronutrients.MacroBody(sugar=0.,fat=0.,amino=0.,tissue=50.)
    RB.Macronutrients.advance!(dead,RB.Macronutrients.MacroParameters(),1.)
    @test !dead.alive
    @test_throws ArgumentError RB.Macronutrients.feed!(dead,(20.,0.,0.),RB.MACRO_PARAMETERS)
end
