using Test
include("run.jl")

@testset "macro body: material and energy contracts" begin
    p=MacroParameters()
    b=MacroBody(); initial=nutrient_energy(b)
    @test feed!(b,(80.0,80.0,80.0),p)==120.0
    @test b.rejected==120.0
    @test nutrient_energy(b)==initial+120.0
    @test_throws ArgumentError feed!(b,(-1.0,0.0,0.0),p)
    @test_throws ArgumentError advance!(b,p,-1.0)
    before=body_snapshot(b,p); advance!(b,p,0.0)
    @test body_snapshot(b,p)==before
    # Sleeping cannot repair without amino material (turnover recycle disabled).
    no_material=MacroBody(tissue=90.0,amino=0.0)
    no_turnover=MacroParameters(turnover_rate=0.0)
    advance!(no_material,no_turnover,1.0;sleeping=true)
    @test no_material.tissue==90.0
    no_energy=MacroBody(sugar=0.0,fat=0.0,tissue=50.0,amino=0.0)
    advance!(no_energy,p,1.0;sleeping=true)
    @test no_energy.repaired==0.0 && no_energy.unmet>0
    awake=MacroBody(tissue=90.0); asleep=deepcopy(awake)
    advance!(awake,p,1.0); advance!(asleep,p,1.0;sleeping=true)
    @test asleep.repaired>awake.repaired
    # Fat pays demand without increasing sugar; empty gut and amino pool isolate it.
    fat_only=MacroBody(sugar=0.0,amino=0.0)
    advance!(fat_only,no_turnover,1.0)
    @test fat_only.fat<200.0 && fat_only.sugar==0.0
    mixed=simulate()
    @test mixed.max_energy_error<1e-7
    @test mixed.final.ingested==900.0 && mixed.final.rejected==0.0
    @test mixed.final.unmet==0.0
    @test length(mixed.daily)==10
    @test all(x->x.intake==90.0,mixed.daily)
    fasting=simulate(days=10,meal_scale=0.0)
    @test fasting.max_energy_error<1e-7
    @test fasting.final.fat<mixed.final.fat
    @test fasting.final.tissue<mixed.final.tissue
    fine=simulate(dt=1/24)
    @test abs(fine.final.fat-mixed.final.fat)<1.0
    @test abs(fine.final.sugar-mixed.final.sugar)<1.0
    @test isapprox(p.body_demand_sugar_weight+p.body_demand_fat_weight+p.body_demand_tissue_weight,1.0)
    depleted=MacroBody(sugar=0.0,fat=0.0,tissue=50.0,amino=0.0)
    @test body_signals(depleted,p).body_demand==1.0
    @test body_signals(MacroBody(sugar=0.0,amino=0.0),p).body_demand≈p.body_demand_sugar_weight+p.body_demand_tissue_weight
    @test body_signals(MacroBody(fat=0.0),p).body_demand>body_signals(MacroBody(),p).body_demand
    half_sugar=body_signals(MacroBody(sugar=15.0),p)
    @test half_sugar.sugar_need==0.5
    @test half_sugar.sugar_demand==0.25
    @test half_sugar.body_demand≈0.25/3
    @test body_signals(MacroBody(sugar=0.0),p).body_demand≈1/3
    @test body_signals(MacroBody(sugar=15.0),MacroParameters(body_demand_squared=false)).body_demand≈0.5/3
end
