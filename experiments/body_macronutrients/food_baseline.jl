# Temporary prescribed feeding/activity calibration ONLY. No MB or food selection.
# Three equal portions at hours 2,8,14; quantities are item equivalents, not actions.
# Does not change production physiology, foods, supply or taste.
using JSON3, Test, Statistics
include("../../src/body/RDLBody.jl")
include("../../src/lw/configured_paths/body_local_cycle.jl")
const FB=RDLBody;const FM=FB.Macronutrients
const FOOD_BASELINE=(days=30,dt=1/60,meal_hours=(2.,8.,14.),sleep_hour=16.,
    initial_fraction=.7,quantities=(2.,3.,3.25,4.,4.5,5.))
const FOOD_BASELINE_DIETS=(fruit=FB.FOOD_COMPOSITION[1],acorn=FB.FOOD_COMPOSITION[4],
    fish=FB.FOOD_COMPOSITION[7],meat=FB.FOOD_COMPOSITION[2],
    mixed=ntuple(i->sum(FB.FOOD_COMPOSITION[k][i] for k in (1,4,7))/3,3))
function food_baseline_run(shares,quantity,activity;dt=FOOD_BASELINE.dt)
    p=FB.MACRO_PARAMETERS
    b=FB.MacroBridge(100FOOD_BASELINE.initial_fraction,17280.).body
    initial=FM.nutrient_energy(b);daily=Any[];death_hour=nothing;max_error=0.
    ticks=round(Int,24/dt);meal_ticks=round.(Int,FOOD_BASELINE.meal_hours./dt)
    for day in 1:FOOD_BASELINE.days
        before=FM.body_snapshot(b,p);demand_sum=0.;living_ticks=0
        for tick in 0:ticks-1
            hour=tick*dt
            if b.alive && tick in meal_ticks
                FM.feed!(b,ntuple(i->quantity*FB.MEAL_ENERGY*shares[i]/length(meal_ticks),3),p)
            end
            phase=configured_body_phase(hour)
            intensity=activity=="rest" ? 0. : phase.intensity
            if b.alive
                living_ticks+=1;demand_sum+=FM.body_signals(b,p).body_demand
            end
            FM.advance!(b,p,dt;intensity,sleeping=hour>=FOOD_BASELINE.sleep_hour)
            !b.alive && death_hour===nothing && (death_hour=(day-1)*24+hour+dt)
            error=initial+b.ingested-FM.nutrient_energy(b)-b.spent-b.conversion_loss-b.excreted
            max_error=max(max_error,abs(error))
        end
        after=FM.body_snapshot(b,p)
        push!(daily,(;day,alive=b.alive,intake=after.ingested-before.ingested,
            spent=after.spent-before.spent,conversion_loss=after.conversion_loss-before.conversion_loss,
            excreted=after.excreted-before.excreted,body_change=after.energy-before.energy,
            gut_change=after.gut-before.gut,sugar=b.sugar,fat=b.fat,tissue=b.tissue,amino=b.amino,
            demand=living_ticks>0 ? demand_sum/living_ticks : nothing))
    end
    tail=b.alive ? daily[end-6:end] : nothing
    (;quantity,activity,shares,death_day=death_hour===nothing ? nothing : death_hour/24,
      final=FM.body_snapshot(b,p),max_error,daily,
      final_week=tail===nothing ? nothing : (;intake=mean(x.intake for x in tail),
        spent=mean(x.spent for x in tail),loss=mean(x.conversion_loss+x.excreted for x in tail),
        absorbed_body_change=mean(x.body_change-x.gut_change for x in tail),
        demand=mean(x.demand for x in tail)))
end
out=abspath(only(ARGS));ispath(out) && error("fresh output required");mkpath(out)
cp(@__FILE__,joinpath(out,"runner.jl"))
cp(joinpath(@__DIR__,"../../src/body"),joinpath(out,"body_source"))
cp(joinpath(@__DIR__,"../../src/lw/configured_paths/body_local_cycle.jl"),joinpath(out,"body_local_cycle.jl"))
results=Any[]
@testset "food baseline material balance" begin
    for activity in ("rest","explore"), quantity in FOOD_BASELINE.quantities, (name,shares) in pairs(FOOD_BASELINE_DIETS)
        trial=food_baseline_run(shares,quantity,activity)
        @test trial.max_error<1e-6
        @test trial.final.rejected==0
        @test all(x->isapprox(x.intake-x.spent-x.conversion_loss-x.excreted,x.body_change;atol=1e-7),trial.daily)
        push!(results,merge((;food=string(name)),trial))
        println(JSON3.write((;food=name,quantity,activity,death_day=trial.death_day,
            tissue=trial.final.tissue,fat=trial.final.fat,final_week=trial.final_week)))
    end
    # Step-size sensitivity at the central quantity, both activity profiles.
    for trial in filter(x->x.quantity==3,results)
        finer=food_baseline_run(trial.shares,3,trial.activity;dt=FOOD_BASELINE.dt/2)
        @test finer.final.alive==trial.final.alive
        @test abs(finer.final.tissue-trial.final.tissue)<1.
        @test abs(finer.final.fat-trial.final.fat)<1.
    end
end
write(joinpath(out,"result.json"),JSON3.write((conditions=FOOD_BASELINE,results,
    note="Game-model E, not grams or clinical calories. Loss includes endogenous turnover; not an intrinsic food efficiency.")))
write(joinpath(out,"completed.json"),JSON3.write((days=FOOD_BASELINE.days,conditions=length(results))))
