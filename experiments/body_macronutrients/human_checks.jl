using Test, Serialization
include("../../src/lw/LW.jl")
if !isdefined(LW,:incidental_item_state)
    Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/decision/incidental_items.jl")))
end
const B=LW.RDLBody
const M=B.Macronutrients
@testset "human tissue starvation, no reserve" begin
    gut=LW.Digestion(macronutrients=true)
    human=LW.HumanBody(gut.macro_body.body,gut.macro_body.hours_per_second)
    @test !hasproperty(human,:reserve)
    @test !haskey(LW.bodydict(human),"reserve")
    human.nutrients.sugar=0.;human.nutrients.fat=0.;human.nutrients.amino=0.
    human.nutrients.tissue=90.
    gut.macro_body.initial_energy=M.nutrient_energy(human.nutrients)
    @test LW.body_alive(human)
    @test !LW.configured_collapse_active(human)
    @test LW.can_ingest(gut)
    walking,status,distance,delta=LW.step(human,"walk",0)
    @test status=="performed" && distance>0
    @test haskey(delta,"energy") && !haskey(delta,"reserve")
    original=deepcopy(human.nutrients)
    forecast=LW.metabolize(walking,360.)
    @test all(getfield(original,k)==getfield(human.nutrients,k) for k in fieldnames(M.MacroBody))
    @test forecast.nutrients.tissue<original.tissue
    @test LW.body_mobility(forecast)<LW.body_mobility(human)
    memory=LW.D()
    LW.food_remember_taste!(memory,B.FRUIT_FOOD,2,1.,0)
    @test isfinite(LW.food_trade_weight(human,gut,B.FRUIT_FOOD;map=memory))
    @test LW.food_social_context(human)["need"]==LW.body_demand(human)
    incidental=LW.incidental_item_state("npc_a",13)
    parent=LW.BasicLoop("npc_a:food";probabilistic=true,seed=17)
    item_view=LW.D("visible"=>[LW.D("ref"=>1,"color"=>"cyan","size"=>.12,"light_source"=>.02,
        "distance"=>.5,"forward"=>.5,"right"=>0.,"holder"=>nothing,"location"=>1)],
        "own_load"=>LW.D("mass"=>0.),"carry_capacity"=>LW.D("mass"=>5.,"size"=>1.))
    @test !isempty(LW.incidental_item_candidates(incidental,item_view,human,parent;family="food"))
    hunger=LW.hunger_state("npc_a")
    LW.hunger_update!(hunger,"npc_a",0,LW.body_energy(human);body_demand=LW.body_demand(human))
    @test isfinite(LW.hunger_relief_score(hunger,LW.body_energy(human),30.,1.,1.))
    # Ingestion still works at zero fast fuels, without instant energy credit.
    LW.ingest!(gut,B.FRUIT_FOOD,LW.body_energy(human),0)
    @test human.nutrients.sugar==0
    human=LW.digest!(gut,human,360.)
    @test LW.body_alive(human)
    @test gut.eaten==1 && human.nutrients.spent>0
    @test abs(LW.digestion_snapshot(gut)["energy_residual"])<1e-6
    # Humans reach a recoverable floor; the cognition gate stops active actions.
    for tick in 1:10000
        human=LW.digest!(gut,human,60.)
        LW.configured_collapse_active(human) && break
    end
    @test LW.body_alive(human)
    @test human.nutrients.tissue==B.MACRO_PARAMETERS.tissue_minimum
    @test LW.configured_collapse_active(human;enabled=false)
    @test LW.can_ingest(gut)
    @test LW.step(human,"eat",0)[2]=="incapacitated"
    @test LW.step(human,"walk",0)[3]==0
    unmet_before=human.nutrients.unmet
    LW.digest!(gut,human,3600.)
    @test human.nutrients.unmet>unmet_before
    @test human.nutrients.tissue==B.MACRO_PARAMETERS.tissue_minimum
    @test abs(LW.digestion_snapshot(gut)["energy_residual"])<1e-6
    io=IOBuffer();serialize(io,(human,gut));seekstart(io)
    restored,restored_gut=deserialize(io)
    @test restored.nutrients===restored_gut.macro_body.body
    @test LW.body_alive(restored) && LW.configured_collapse_active(restored)
    world=LW.world(true);world.bodies["npc_a"]=human
    counters=LW.D("npc_a"=>LW.D());events=Any[]
    LW.configured_collapse_tick!(LW.D(),world,"npc_a",counters,events,LW.D(),1)
    @test counters["npc_a"]["collapsed"]==1
    @test only(events)["selection_mode"]=="physical"
    # Nutrients repair tissue; no energy/body reset on assistance.
    for kind in (B.FRUIT_FOOD,B.FRUIT_FOOD,B.COOKED_FISH)
        LW.ingest!(gut,kind,LW.body_energy(human),0)
    end
    @test LW.configured_collapse_active(human)
    human=LW.digest!(gut,human,360.;sleeping=true)
    @test LW.body_alive(human) && !LW.configured_collapse_active(human)
    @test human.nutrients.tissue>B.MACRO_PARAMETERS.tissue_minimum
    @test abs(LW.digestion_snapshot(gut)["energy_residual"])<1e-6
end
