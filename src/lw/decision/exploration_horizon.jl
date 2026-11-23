# Observed distant-feature movement options. Legacy cross-day pressure removed.
horizon_state(actor)=D("actor"=>actor,"H"=>0,"threshold"=>2,"count"=>0,"charged"=>nothing,"events"=>Any[],"selections"=>0)
function horizon_result!(s,actor,op,phase,status,acquired;linked=true)
    actor==s["actor"] || error("horizon_binding")
    (!linked || op==s["charged"]) && return false
    # Compatibility fields only. Exploration pressure belongs to each forecast,
    # not to a global count of movements. Clear legacy counters on resumed runs.
    s["charged"]=op;s["H"]=0;s["count"]=0
    true
end
function horizon_candidates(s,fan,move)
    safe=[Int(ANGLES[i]) for i in 1:5 if move["energy"]["rows"][i]["cost"]!==nothing]
    out=Dict{Int,Any}()
    for (i,f) in enumerate(fan["features"])
        f["range_band"] in ("mid","far") || continue
        lo,hi=f["azimuth"];hi-lo<=45 && !isempty(safe) || continue
        center=(lo+hi)/2;angle=safe[argmin(abs.(safe .- center))]
        abs(angle-center)<=22.5 || continue
        score=2. # Existing baseline salience; no legacy H-dependent bonus.
        if !haskey(out,angle) || score>out[angle]["priority"]
            out[angle]=D("method"=>"horizon_$angle","action"=>"walk","direction"=>findfirst(==(angle),ANGLES)-1,
                "priority"=>score,"question"=>"movement_progress","horizon_source"=>fan["source"],"feature_index"=>i)
        end
    end
    [out[a] for a in sort(collect(keys(out)))]
end
