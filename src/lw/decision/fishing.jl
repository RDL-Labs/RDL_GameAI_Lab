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
    # Acquisition selected this method/site including its uncertain forecast.
    # Arrival executes that decision, rather than sampling the same choice twice.
    # The caller still checks parent purpose, safety, body and observed proximity.
    D("action"=>"fish","method"=>"fish",
      "food_ref"=>target["ref"],"fishing_forecast"=>get(target,"acquisition_seconds",720.))
end
