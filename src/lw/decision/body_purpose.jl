# Finite body-maintenance parent MB; lower purposes remain pending.
body_purpose_state(actor)=D("id"=>"$actor:energy-maintenance","actor"=>actor,"goal"=>"energy_maintenance","parent"=>"$actor:life",
    "replenishing"=>false,"selected"=>nothing,"decisions"=>0,"food_overrides"=>0,"switches"=>0,"records"=>Any[])
function body_purpose!(s,h,reserve,return_requested,at_home,local_stock,now)
    s["actor"]==h["actor"] || error("body_purpose_owner")
    reserve>80 && (s["replenishing"]=false)
    hunger_select(h) && (s["replenishing"]=true)
    # Only currently accessible, observed storage is supplied by the adapter.
    replenish=s["replenishing"]
    family=replenish ? (at_home && local_stock>0 ? "home" : "food") : return_requested ? "home" : "food"
    s["decisions"]+=1
    s["food_overrides"]+=Int(replenish && return_requested && family=="food")
    if s["selected"]!=family
        s["switches"]+=1
        push!(s["records"],D("source"=>"ob:$now:$(s["actor"])","from"=>s["selected"],"to"=>family,
            "reserve"=>reserve,"hunger_pressure"=>h["intensity"],"replenishing"=>replenish,
            "return_pending"=>return_requested))
        length(s["records"])>32 && popfirst!(s["records"])
    end
    s["selected"]=family
    (returning=family=="home",replenishing=replenish)
end
