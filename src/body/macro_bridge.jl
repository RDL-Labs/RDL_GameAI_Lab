# Physical integration adapter. E and hours, not clinical concentrations.
# Legacy scene reserve is accepted only as an initial-pool input conversion.
const MACRO_PARAMETERS = Macronutrients.MacroParameters(starvation_fatal=false)
const MACRO_WALK_INTENSITY = 0.65 # same exploratory load as the local calibration
const MACRO_INITIAL_POOLS = (sugar=32.,fat=200.,amino=8.)
mutable struct MacroBridge
    body::Macronutrients.MacroBody
    initial_energy::Float64
    hours_per_second::Float64
end
function MacroBridge(reserve, day_seconds)
    isfinite(day_seconds) && day_seconds>0 || error("macro day length")
    fraction=clamp(reserve/100,0.,1.)
    body=Macronutrients.MacroBody(sugar=MACRO_INITIAL_POOLS.sugar*fraction,
        fat=MACRO_INITIAL_POOLS.fat*fraction,tissue=MACRO_PARAMETERS.tissue_target,
        amino=MACRO_INITIAL_POOLS.amino)
    MacroBridge(body,Macronutrients.nutrient_energy(body),24/day_seconds)
end
function macro_digest!(g,b,seconds;action="rest",sleeping=false)
    bridge=g.macro_body
    physical=bridge.body
    old_gut=sum(physical.gut)
    intensity=sleeping ? 0. : b.activity
    Macronutrients.advance!(physical,MACRO_PARAMETERS,seconds*bridge.hours_per_second;
        intensity,sleeping)
    g.absorbed+=old_gut-sum(physical.gut)
    g.gut_components=ntuple(i->physical.gut[i]/MEAL_ENERGY,3)
    g.gut=sum(g.gut_components)
    signals=Macronutrients.body_signals(physical,MACRO_PARAMETERS)
    g.nutrient_stores=ntuple(i->NUTRIENT_TARGET[i]*(1-(signals.sugar_need,
        signals.protein_need,signals.fat_need)[i]),3)
    g.recent .*= exp(-seconds/7200)
    HumanBody(b.burst,b.strain,b.damage,physical,bridge.hours_per_second,0.)
end
