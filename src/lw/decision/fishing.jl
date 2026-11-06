function fishing_observation!(r,a,visible)
    r===nothing && return
    for v in visible
        get(v,"acquisition","pickup")=="fishing" || continue
        s=fishing_state!(r,a)
        estimate=game_fishing_forecast(r.game.enabled ? get(r.game.skills,a,D()) : D(),get(s["sites"],string(v["ref"]+1),D());prior_base=get(v,"appearance","")=="river_water" ? .05 : .25)
        v["fishing_probability"]=estimate.probability
        v["acquisition_seconds"]=estimate.seconds
        v["acquisition_uncertainty"]=1-estimate.probability
    end
end
function fishing_plan!(r,a,loop,target,now)
    s=fishing_state!(r,a)
    active=s["active"]
    if active!==nothing && active["site"]==target["ref"]+1 && active["last_us"]+1_000_000==now
        return D("action"=>"fish","method"=>"fish","food_ref"=>target["ref"],"fishing_forecast"=>get(target,"acquisition_seconds",720.))
    end
    p=get(target,"fishing_probability",.25)
    field=relational_transition(0.,1.;probability=p,cost=GAME_FISHING_TICKS/1800.)
    candidates=[D("method"=>"fish","priority"=>log(max(.001,field.expected))),D("method"=>"look_elsewhere","priority"=>-2.)]
    probabilities=method_distribution(loop,candidates)
    chosen=rand(loop.rng)<probabilities[1]
    D("action"=>chosen ? "fish" : "scan","method"=>chosen ? "fish" : "fishing_look_elsewhere",
      "food_ref"=>target["ref"],"fishing_forecast"=>get(target,"acquisition_seconds",720.))
end
