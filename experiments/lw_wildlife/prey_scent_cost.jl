# Cost probe: observe the OFF trajectory but never apply scent to choices.
include("animals_only.jl")
function scent_cost_probe()
    s,predators=animal_trial_world(;adult_rabbits=95)
    scents=PredatorScentWorld(2);minds=[PredatorMind(i) for i in 1:2]
    prey_scents=PreyScentWorld(2);nanoseconds=UInt64(0);calls=0
    # Compile with disposable state, not the measured trace or random stream.
    configured_prey_scent_tick!(PreyScentWorld(2),s,predators,0)
    daily=Any[]
    for t in 0:3*17280-1
        animal_trial_step!(s,predators,t;scents,minds,prey_nutrition=1.5)
        # Includes deposits and sniffs, excludes steering. No world mutations.
        started=time_ns();configured_prey_scent_tick!(prey_scents,s,predators,t)
        nanoseconds+=time_ns()-started;calls+=1
        (t+1)%17280==0 && push!(daily,animal_trial_report(s,predators;scents,minds))
    end
    expected=JSON3.read(read(ARGS[1],String))
    for day in 1:3
        @assert JSON3.read(JSON3.write(daily[day]))==expected.daily[day].report
    end
    result=(seconds=nanoseconds/1e9,calls=calls,source="OFF trajectory, after each world step; timer overhead included; steering excluded",
        off_daily_matches=true,scent=prey_scent_report(prey_scents))
    write(ARGS[2],JSON3.write(result));println(JSON3.write(result))
end
scent_cost_probe()
