include("compare.jl")
# Diagnostic coefficient sweep. Physiology and fixed schedule remain unchanged.
# All weights sum to 1; do not globally compress the range of the demand signal.
const DEMAND_WEIGHT_TRIALS=(
    original=(0.65,0.20,0.15),mild=(0.55,0.30,0.15),balanced=(0.45,0.40,0.15))
function demand_tuning_main()
    length(ARGS)==1 || error("usage: tune_demand.jl NEW_OUTPUT_JSON")
    ispath(ARGS[1]) && error("output exists")
    report=Dict{String,Any}()
    for (diet,shares) in pairs(DIET_COMPARISON)
        run=simulate(meal_shares=shares)
        records=filter(x->x.day==10 && x.phase!="end",run.timeline)
        report[string(diet)]=Dict{String,Any}()
        for (trial,weights) in pairs(DEMAND_WEIGHT_TRIALS)
            p=MacroParameters(body_demand_squared=false,body_demand_sugar_weight=weights[1],body_demand_fat_weight=weights[2],
                              body_demand_tissue_weight=weights[3])
            demands=[body_signals(MacroBody(;sugar=x.sugar,fat=x.fat,tissue=x.tissue,amino=x.amino,
                                    gut=(x.gut,0.0,0.0)),p).body_demand for x in records]
            mean=sum(d for (x,d) in zip(records,demands) if x.phase!="before_meal")/
                 count(x->x.phase!="before_meal",records)
            report[string(diet)][string(trial)]=(;mean,maximum=maximum(demands),weights)
        end
    end
    write(ARGS[1],JSON3.write(report));println(JSON3.write(report))
end
demand_tuning_main()
