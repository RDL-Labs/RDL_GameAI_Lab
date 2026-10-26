# Initial bodily preference, separate from configured action paths and earned reward.
# "home" is the initial rest-site hypothesis, never a hidden coordinate or route.
embedded_rest_state()=D("place"=>"home","awake_seconds"=>0.,"last_us"=>nothing,
    "need"=>0.,"place_value"=>.8,"requested"=>false,"probability"=>0.,
    "decisions"=>0,"selections"=>0,"food_blocks"=>0,"window"=>0,"rested"=>0,
    "experience"=>Float64[],"records"=>Any[])
function embedded_rest_request!(state,strain,reserve,hunger,replenishing,scheduled,now,day_us,rng)
    # A bounded sleep-need proxy, not a claim about human physiology.
    need=clamp(max(strain,state["awake_seconds"]/(.5day_us/1_000_000)),0.,1.)
    value=state["place_value"]
    food_pressure=max(hunger,clamp((80-reserve)/60,0.,1.))
    probability=need/(1+exp(1+6food_pressure-8need*value))
    state["need"]=need;state["probability"]=probability;state["decisions"]+=1
    # Existing body-maintenance intervention still takes precedence during urgent hunger.
    chosen=!replenishing && (scheduled || rand(rng)<probability)
    state["food_blocks"]+=Int(replenishing);state["requested"]=chosen
    state["selections"]+=Int(chosen)
    if mod(state["decisions"],64)==1
        push!(state["records"],D("us"=>now,"need"=>need,"place_value"=>value,"food_pressure"=>food_pressure,
            "probability"=>probability,"scheduled"=>scheduled,"replenishing"=>replenishing,"chosen"=>chosen))
        length(state["records"])>64 && popfirst!(state["records"])
    end
    # Preserve other requested home goals (including accessible food at home).
    scheduled || chosen
end
function embedded_rest_feedback!(state,at_home,action,status,now,day_us)
    state["last_us"]!==nothing && now<=state["last_us"] && return
    state["last_us"]=now
    resting=action=="rest" && status=="performed"
    state["awake_seconds"]=clamp(state["awake_seconds"]+(resting ? -4. : 1.),0.,day_us/1_000_000)
    if state["requested"] && at_home
        state["window"]+=1;state["rested"]+=Int(resting)
        if state["window"]==60
            push!(state["experience"],state["rested"]/60)
            length(state["experience"])>64 && popfirst!(state["experience"])
            # Prior strength five observations; later evidence can revise the initial preference.
            state["place_value"]=(4+sum(state["experience"] ))/(5+length(state["experience"]))
            state["window"]=0;state["rested"]=0
        end
    elseif !at_home
        state["window"]=0;state["rested"]=0
    end
end
