module Macronutrients

export MacroParameters, MacroBody, nutrient_energy, feed!, advance!, body_signals, body_snapshot

# Experimental game physiology, NOT measured human rates. All pools use a common
# energy-equivalent unit E (including protein material), time is hours. No grams,
# blood glucose concentration, hormones or individual amino acids are represented.
# Defaults are provisional; species-specific callers may supply another parameter set.
Base.@kwdef struct MacroParameters
    # World/body rule: humans may remain incapacitated at the tissue floor.
    # Default keeps standalone physiology and other callers' fatal starvation.
    starvation_fatal::Bool = true
    sugar_capacity::Float64 = 45.0
    sugar_reference::Float64 = 30.0
    fat_capacity::Float64 = 400.0
    fat_reference::Float64 = 200.0
    tissue_target::Float64 = 100.0
    tissue_minimum::Float64 = 50.0
    amino_capacity::Float64 = 12.0
    amino_reference::Float64 = 6.0
    gut_capacity::Float64 = 120.0
    absorption_rate::Float64 = 18.0 # total E/hour, common mixed digestion
    basal_rate::Float64 = 2.0
    tissue_maintenance_rate::Float64 = 0.002 # E/hour per tissue E
    activity_rate::Float64 = 4.0 # E/hour at intensity 1
    resting_fat_share::Float64 = 0.65
    intensity_fat_reduction::Float64 = 0.35
    low_sugar_fat_support::Float64 = 0.25
    fat_release_rate::Float64 = 6.0 # E/hour; cannot pay arbitrary instantaneous demand
    turnover_rate::Float64 = 0.025 # tissue E/hour
    activity_wear_rate::Float64 = 0.06 # tissue E/hour at intensity 1
    recycle_fraction::Float64 = 0.75
    awake_repair_rate::Float64 = 0.025
    sleep_repair_rate::Float64 = 0.30
    repair_energy_cost::Float64 = 0.35 # additional E per repaired tissue E
    gluconeogenesis_rate::Float64 = 2.0 # amino E/hour at full sugar deficit
    gluconeogenesis_efficiency::Float64 = 0.80
    sugar_storage_rate::Float64 = 3.0 # excess sugar E/hour
    storage_efficiency::Float64 = 0.85
    # Equal weights; nutrient-specific dynamics belong to metabolism. Square each
    # normalized deficit BEFORE combining. false retains the linear comparison.
    body_demand_squared::Bool = true
    body_demand_sugar_weight::Float64 = 1/3
    body_demand_fat_weight::Float64 = 1/3
    body_demand_tissue_weight::Float64 = 1/3
    gut_satiety_weight::Float64 = 0.60
end

Base.@kwdef mutable struct MacroBody
    alive::Bool = true
    sugar::Float64 = 32.0
    fat::Float64 = 200.0
    tissue::Float64 = 100.0
    amino::Float64 = 8.0
    gut::NTuple{3,Float64} = (0.0,0.0,0.0) # carbohydrate, protein, fat; same order as Digestion
    ingested::Float64 = 0.0
    rejected::Float64 = 0.0
    spent::Float64 = 0.0
    conversion_loss::Float64 = 0.0
    excreted::Float64 = 0.0
    unmet::Float64 = 0.0
    sugar_used::Float64 = 0.0
    fat_used::Float64 = 0.0
    amino_used::Float64 = 0.0
    tissue_used::Float64 = 0.0
    repaired::Float64 = 0.0
    converted_to_sugar::Float64 = 0.0
    stored_fat::Float64 = 0.0
end

nutrient_energy(b::MacroBody) = b.sugar+b.fat+b.tissue+b.amino+sum(b.gut)

function feed!(b::MacroBody, meal::NTuple{3,<:Real}, p::MacroParameters)
    b.alive || throw(ArgumentError("cannot feed a dead body"))
    all(x->isfinite(x) && x>=0,meal) || throw(ArgumentError("nonnegative finite meal"))
    offered=sum(meal)
    accepted=min(offered,max(0.0,p.gut_capacity-sum(b.gut)))
    fraction=offered>0 ? accepted/offered : 0.0
    b.gut=ntuple(i->b.gut[i]+fraction*meal[i],3)
    b.ingested+=accepted; b.rejected+=offered-accepted
    accepted
end

# Store a transfer once; loss/overflow never vanish from the energy ledger.
function store_fat!(b,p,source)
    usable=source*p.storage_efficiency
    stored=min(usable,max(0.0,p.fat_capacity-b.fat))
    b.fat+=stored; b.stored_fat+=stored
    b.conversion_loss+=source-usable; b.excreted+=usable-stored
end

function advance!(b::MacroBody,p::MacroParameters,dt::Real;intensity::Real=0.0,sleeping::Bool=false)
    isfinite(dt) && dt>=0 && isfinite(intensity) && 0<=intensity<=1 || throw(ArgumentError("time/intensity"))
    (dt==0 || !b.alive) && return b
    # Digestion transfers existing material, does not create an extra reserve credit.
    gut_total=sum(b.gut)
    fraction=gut_total>0 ? min(1.0,p.absorption_rate*dt/gut_total) : 0.0
    absorbed=ntuple(i->b.gut[i]*fraction,3)
    b.gut=ntuple(i->max(0.0,b.gut[i]-absorbed[i]),3)
    b.sugar+=absorbed[1]; b.amino+=absorbed[2]; b.fat+=absorbed[3]

    # Turnover/wear: recycled material is transferred; net loss is explicitly logged.
    wear=min(max(0.0,b.tissue-p.tissue_minimum),(p.turnover_rate+p.activity_wear_rate*intensity)*dt)
    b.tissue-=wear; b.amino+=wear*p.recycle_fraction
    b.excreted+=wear*(1-p.recycle_fraction)

    sugar_deficit=clamp(1-b.sugar/p.sugar_reference,0.0,1.0)
    converted=min(b.amino,p.gluconeogenesis_rate*sugar_deficit*dt,
                  max(0.0,p.sugar_reference-b.sugar)/p.gluconeogenesis_efficiency)
    b.amino-=converted; b.sugar+=converted*p.gluconeogenesis_efficiency
    b.converted_to_sugar+=converted*p.gluconeogenesis_efficiency
    b.conversion_loss+=converted*(1-p.gluconeogenesis_efficiency)

    # Tissue maintenance is an energy demand, not direct tissue destruction.
    demand=(p.basal_rate+p.tissue_maintenance_rate*b.tissue+p.activity_rate*intensity)*dt
    fat_share=clamp(p.resting_fat_share-p.intensity_fat_reduction*intensity+
                    p.low_sugar_fat_support*sugar_deficit,0.0,1.0)
    fat_budget=p.fat_release_rate*dt
    fat_take=min(b.fat,fat_budget,demand*fat_share)
    b.fat-=fat_take; b.fat_used+=fat_take; fat_budget-=fat_take
    remaining=demand-fat_take
    sugar_take=min(b.sugar,remaining)
    b.sugar-=sugar_take; b.sugar_used+=sugar_take; remaining-=sugar_take
    extra_fat=min(b.fat,fat_budget,remaining)
    b.fat-=extra_fat; b.fat_used+=extra_fat; fat_budget-=extra_fat; remaining-=extra_fat
    amino_take=min(b.amino,remaining)
    b.amino-=amino_take; b.amino_used+=amino_take; remaining-=amino_take
    tissue_take=min(max(0.0,b.tissue-p.tissue_minimum),remaining)
    b.tissue-=tissue_take; b.tissue_used+=tissue_take; remaining-=tissue_take
    b.spent+=demand-remaining; b.unmet+=remaining
    if b.tissue<=p.tissue_minimum && p.starvation_fatal
        b.alive=false
        return b
    end

    # Sleep speeds repair, but neither supplies amino material nor free energy.
    repair_rate=sleeping ? p.sleep_repair_rate : p.awake_repair_rate
    repair_energy=b.sugar+min(b.fat,fat_budget)
    repair=remaining>1e-12 ? 0.0 : min(max(0.0,p.tissue_target-b.tissue),b.amino,
                                      repair_rate*dt,repair_energy/p.repair_energy_cost)
    repair_cost=repair*p.repair_energy_cost
    repair_sugar=min(b.sugar,repair_cost)
    repair_fat=repair_cost-repair_sugar
    b.sugar-=repair_sugar; b.fat-=repair_fat
    b.sugar_used+=repair_sugar; b.fat_used+=repair_fat
    b.amino-=repair; b.tissue+=repair; b.repaired+=repair; b.spent+=repair_cost

    # Reserve caps: overflow material has an explicit fate. No silent clipping.
    sugar_surplus=min(max(0.0,b.sugar-p.sugar_reference),p.sugar_storage_rate*dt)
    sugar_surplus=max(sugar_surplus,max(0.0,b.sugar-p.sugar_capacity))
    b.sugar-=sugar_surplus; store_fat!(b,p,sugar_surplus)
    amino_surplus=max(0.0,b.amino-p.amino_capacity)
    b.amino-=amino_surplus; store_fat!(b,p,amino_surplus)
    fat_overflow=max(0.0,b.fat-p.fat_capacity)
    b.fat-=fat_overflow; b.excreted+=fat_overflow
    b
end

function body_signals(b::MacroBody,p::MacroParameters;pending_nutrition=false)
    # Eating decision only: exact queued C/P/F, without simulating absorption or
    # conversion. Physical callers keep the default absorbed pools. No mutation.
    pending_sugar,pending_protein,pending_fat=pending_nutrition ? b.gut : (0.,0.,0.)
    pending_repair=max(0.,pending_protein-max(0.,p.amino_reference-b.amino))
    sugar_need=clamp(1-(b.sugar+pending_sugar)/p.sugar_reference,0.0,1.0)
    fat_need=clamp(1-(b.fat+pending_fat)/p.fat_reference,0.0,1.0)
    tissue_need=clamp((p.tissue_target-b.tissue-pending_repair)/(p.tissue_target-p.tissue_minimum),0.0,1.0)
    protein_need=max(tissue_need,clamp(1-(b.amino+pending_protein)/p.amino_reference,0.0,1.0))
    fullness=clamp(sum(b.gut)/p.gut_capacity,0.0,1.0)
    sugar_demand=p.body_demand_squared ? sugar_need*sugar_need : sugar_need
    fat_demand=p.body_demand_squared ? fat_need*fat_need : fat_need
    protein_demand=p.body_demand_squared ? protein_need*protein_need : protein_need
    # Provisional body demand input, not subjective hunger, blood glucose or an MB forecast.
    body_demand=clamp(p.body_demand_sugar_weight*sugar_demand+p.body_demand_fat_weight*fat_demand+
                 p.body_demand_tissue_weight*protein_demand-p.gut_satiety_weight*fullness,0.0,1.0)
    ability=b.alive ? clamp((b.tissue-p.tissue_minimum)/(p.tissue_target-p.tissue_minimum),0.0,1.0) : 0.
    (;body_demand,sugar_need,fat_need,protein_need,sugar_demand,fat_demand,protein_demand,fullness,ability)
end

function body_snapshot(b,p)
    (;alive=b.alive,sugar=b.sugar,fat=b.fat,tissue=b.tissue,amino=b.amino,gut=sum(b.gut),
      repair_need=max(0.0,p.tissue_target-b.tissue),body_signals(b,p)...,
      ingested=b.ingested,rejected=b.rejected,spent=b.spent,conversion_loss=b.conversion_loss,
      excreted=b.excreted,unmet=b.unmet,sugar_used=b.sugar_used,fat_used=b.fat_used,
      amino_used=b.amino_used,tissue_used=b.tissue_used,repaired=b.repaired,
      converted_to_sugar=b.converted_to_sugar,stored_fat=b.stored_fat,energy=nutrient_energy(b))
end
end
