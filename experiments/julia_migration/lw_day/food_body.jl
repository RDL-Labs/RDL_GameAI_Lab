# Ports social_life.advance_metabolism, hunger_review and food_retention.
food_band(n)=n==0 ? "none" : n<=2 ? "low" : n<=5 ? "some" : "many"
function metabolize(b,seconds)
    seconds>=0 || error("metabolic_clock")
    Body(b.burst,b.strain,max(0.,b.reserve-seconds*.25*RS),b.damage)
end
hunger_state(actor)=D("actor"=>actor,"H"=>0,"threshold"=>2,"last_us"=>-1,"due"=>nothing,"intensity"=>0.,"comparisons"=>0,"records"=>Any[])
function hunger_update!(h,actor,now,reserve)
    h["actor"]==actor && now>=h["last_us"] && 0<=reserve<=100 || error("hunger_binding")
    if h["due"]!==nothing && now>=h["due"]
        before=h["H"];h["H"]=reserve>80 ? 0 : before+1;h["comparisons"]+=1
        push!(h["records"],D("trial_due_us"=>h["due"],"source"=>"ob:$now:$actor","reserve"=>reserve,"E"=>Int(reserve<=80),"H_before"=>before,"H_after"=>h["H"]))
        length(h["records"])>32 && popfirst!(h["records"]);h["due"]=nothing
    end
    h["due"]===nothing && reserve<=80 && (h["due"]=now+5_000_000)
    h["last_us"]=now;h["intensity"]=reserve>80 ? 0. : .05+.95*(80-reserve)/80
    h
end
hunger_select(h)=h["intensity"]>0 && .2+h["intensity"]+min(1.,h["H"]/h["threshold"])>.5
function retention_cost(obs,h)
    obs["self_id"]==h["actor"] || error("retention_owner")
    scarcity=Dict("none"=>0.,"low"=>1.,"some"=>.4,"many"=>0.)[food_band(obs["inventory"])]
    reserve=obs["body"]["reserve"]
    scarcity*(1+2*max(0.,(80-reserve)/80)+(reserve<=80 ? min(1.,h["H"]/h["threshold"]) : 0.))
end

# Existing feasible methods only. Reserve depletion is not resolved by rest.
function project_body_methods!(candidates,h,body,phase)
    phase in ("exploration","return") || return false
    urgency=h["intensity"]*(1+min(1.,h["H"]/h["threshold"]))
    fatigue=body.strain;recoverable=min(1.,body.reserve/20);applied=false
    for c in candidates
        get(c,"record_trial",true) || continue
        action=c["action"]
        delta=action=="rest" ? fatigue*recoverable-.5*urgency : action in ("walk","scan") ? .5*urgency-.5*fatigue : nothing
        delta===nothing && continue
        c["priority"]+=delta;applied|=delta!=0
    end
    applied
end
