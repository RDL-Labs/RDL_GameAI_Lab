# Observer only: distances/bands never feed decisions. Counts are animal-ticks,
# not encounters. Sampling is before movement, every tick; totals are cumulative.
proximity_observer()=Dict(name=>Dict{String,Any}("minimum"=>nothing,"minimum_tick"=>nothing,
    "within_3_animal_ticks"=>0,"within_6_animal_ticks"=>0) for name in ("rabbit_home","predator_home","predator_human"))
function proximity_sample!(row,distance,t)
    if row["minimum"]===nothing || distance<row["minimum"]
        row["minimum"]=distance;row["minimum_tick"]=t
    end
    row["within_3_animal_ticks"]+=distance<=3
    row["within_6_animal_ticks"]+=distance<=6
end
function proximity_observe!(stats,wildlife,predators,humans,home,t)
    for i in eachindex(wildlife.alive)
        wildlife.alive[i] || continue
        proximity_sample!(stats["rabbit_home"],hypot(wildlife.animals.x[i]-home[1],wildlife.animals.z[i]-home[2]),t)
    end
    for p in predators
        p.alive || continue
        b=p.visual.body
        proximity_sample!(stats["predator_home"],hypot(b.x-home[1],b.z-home[2]),t)
        isempty(humans) || proximity_sample!(stats["predator_human"],minimum(hypot(b.x-h[1],b.z-h[2]) for h in humans),t)
    end
end
