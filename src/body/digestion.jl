# Minimal game physiology; taste, stored nutrients and absorbed energy are separate.
mutable struct Digestion
    gut::Float64
    recent::Vector{Float64}
    eaten::Int
    absorbed::Float64
    overflow::Float64
    pleasure::Float64
    records::Vector{Any}
    taste_preference::NTuple{3,Float64}
    gut_components::NTuple{3,Float64}
    nutrient_stores::NTuple{3,Float64}
end
const NUTRIENT_TARGET=(0.50,0.25,0.25) # scenario target in food units
# Fixed deviations from the ordinary palate; order is carbohydrate, protein, fat.
Digestion(;taste_preference=(0.,0.,0.))=Digestion(0.,zeros(2),0,0.,0.,0.,Any[],taste_preference)
Digestion(g,r,n,a,o,p,records)=Digestion(g,r,n,a,o,p,records,(0.,0.,0.))
function Digestion(g,r,n,a,o,p,records,preference)
    components=ntuple(i->g*NUTRIENT_TARGET[i],3)
    Digestion(g,r,n,a,o,p,records,preference,components,NUTRIENT_TARGET)
end
# Scenario composition of one food unit. These shares describe sensory differences.
const FOOD_COMPOSITION=(
    (0.95,0.03,0.02), # fruit
    (0.00,0.58,0.42), # meat
    (0.66,0.07,0.27), # raw acorn
    (0.66,0.07,0.27), # prepared acorn
    (0.00,0.82,0.18), # raw fish
    (0.00,0.00,0.00), # spoiled
    (0.00,0.82,0.18), # cooked fish
    (0.00,0.82,0.18)) # salt grilled fish
function food_base_taste(g,kind)
    ordinary=FOOD_LIKING[kind]
    g===nothing && return ordinary
    composition=FOOD_COMPOSITION[kind]
    return ordinary+sum(composition[i]*g.taste_preference[i] for i in 1:3)
end
nutrient_need(g)=ntuple(i->clamp(1-g.nutrient_stores[i]/NUTRIENT_TARGET[i],0.,1.),3)
function nutrient_value(g,kind)
    g===nothing && return 0.
    need=nutrient_need(g)
    return sum(need[i]*FOOD_COMPOSITION[kind][i] for i in 1:3)
end
taste_state_factor(g,reserve)=(1-g.gut/GUT_CAPACITY)*(.5+.5*(1-reserve/100))
const GUT_CAPACITY=2.
const DIGEST_SECONDS=1800.
const MEAL_ENERGY=20.
const FOOD_LIKING=(1.,1.5,-1.,.45,0.,0.,1.5,2.1) # scenario preferences, not biological laws
can_ingest(g)=g.gut<=GUT_CAPACITY-1+1e-12
function taste(g,kind,reserve)
    food_edible(kind) || error("food requires processing or has unknown kind")
    0<=reserve<=100 || error("reserve")
    # Food boredom is deferred; recent remains diagnostic/checkpoint state.
    (food_base_taste(g,kind)+nutrient_value(g,kind))*taste_state_factor(g,reserve)
end
function ingest!(g,kind,reserve,now;quality_bonus=0.0)
    can_ingest(g) || error("gut full")
    liking=taste(g,kind,reserve)+quality_bonus*taste_state_factor(g,reserve)
    # Keep the original two-kind state unchanged until another kind is eaten.
    if kind>length(g.recent)
        old=length(g.recent);resize!(g.recent,kind);g.recent[old+1:end].=0.
    end
    g.gut_components=ntuple(i->g.gut_components[i]+FOOD_COMPOSITION[kind][i],3)
    g.gut+=1; g.recent[kind]=min(1.,g.recent[kind]+.6)
    g.eaten+=1; g.pleasure+=liking
    push!(g.records,(time=now,kind=kind,liking=liking,composition=FOOD_COMPOSITION[kind],nutrient_need=nutrient_need(g),gut_after=g.gut,reserve_at_meal=reserve))
    length(g.records)>32 && popfirst!(g.records)
    liking
end
function digest!(g,b,seconds)
    isfinite(seconds) && seconds>=0 || error("digestion time")
    amount=min(g.gut,seconds/DIGEST_SECONDS)
    fraction=g.gut>0 ? amount/g.gut : 0.
    absorbed=ntuple(i->fraction*g.gut_components[i],3)
    g.gut_components=ntuple(i->max(0.,g.gut_components[i]-absorbed[i]),3)
    # The gut releases its mixture until empty; the remaining time is fasting.
    feeding_time=min(seconds,amount*DIGEST_SECONDS)
    g.nutrient_stores=ntuple(3) do i
        rate=NUTRIENT_TARGET[i]*(.25*RS/MEAL_ENERGY)
        during=clamp(g.nutrient_stores[i]+absorbed[i]-rate*feeding_time,0.,2NUTRIENT_TARGET[i])
        max(0.,during-rate*(seconds-feeding_time))
    end
    g.gut-=amount
    energy=amount*MEAL_ENERGY; used=min(100-b.reserve,energy)
    g.absorbed+=used; g.overflow+=energy-used
    g.recent .*= exp(-seconds/7200)
    Body(b.burst,b.strain,b.reserve+used,b.damage)
end
function digestion_snapshot(g)
    @assert isapprox(g.eaten*MEAL_ENERGY,g.gut*MEAL_ENERGY+g.absorbed+g.overflow;atol=1e-7)
    Dict("nutrient_stores"=>g.nutrient_stores,"nutrient_need"=>nutrient_need(g),"gut_components"=>g.gut_components,"taste_preference"=>g.taste_preference,"gut"=>g.gut,"recent"=>copy(g.recent),"eaten"=>g.eaten,"absorbed"=>g.absorbed,
        "overflow"=>g.overflow,"pleasure"=>g.pleasure,"records"=>copy(g.records))
end
