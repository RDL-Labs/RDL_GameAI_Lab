include("animals_only.jl")
function replay()
    s,records=deserialize(ARGS[1])
    predators=[TrialPredator(values(r)...,-1,0,0) for r in records]
    daily=Any[];runs=zeros(Int,2);longest=zeros(Int,2)
    for t in s.ticks:10*17280-1
        animal_trial_step!(s,predators,t)
        for i in 1:2
            runs[i]=predators[i].mode==:warn ? runs[i]+1 : 0
            longest[i]=max(longest[i],runs[i])
        end
        if (t+1)%17280==0
            r=animal_trial_report(s,predators)
            push!(daily,(day=div(t+1,17280),rabbits=r.rabbits.alive,captures=r.rabbits.predation_deaths,
                births=r.rabbits.reproduction.births,starvation=r.rabbits.starvation_deaths,predators=r.predators))
        end
    end
    result=(start="old day-3 checkpoint; existing fields unchanged; new warning timers initially inactive",
        rule=PREDATOR_ANIMAL_TRIAL,longest_warning=longest,daily=daily)
    @assert maximum(longest)<=PREDATOR_ANIMAL_TRIAL.warning_duration_ticks
    write(ARGS[2],JSON3.write(result))
    println(JSON3.write((longest_warning=longest,final=daily[end])))
end
replay()
