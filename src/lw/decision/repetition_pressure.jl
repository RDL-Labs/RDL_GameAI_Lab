# Local lack-of-change pressure; separate from task failure and Core H.
repetition_state()=D("nodes"=>D(),"previous"=>nothing,"last_us"=>-1,"additions"=>0,"projections"=>0,"changes"=>0)
function repetition_result!(s,source,now,method,view;changed=false,decay=.1)
    check(isfinite(decay) && decay>=0,"repetition_decay")
    check(now>s["last_us"],"repetition_order")
    dt=s["last_us"]<0 ? 0. : (now-s["last_us"])/1e6
    for k in keys(s["nodes"]);s["nodes"][k]=max(0.,s["nodes"][k]-decay*dt);end
    prior=s["previous"]
    if method!==nothing && !changed && prior!==nothing && prior.method==method && prior.view==view
        if haskey(s["nodes"],method) || length(s["nodes"])<64
            s["nodes"][method]=min(32.,get(s["nodes"],method,0.)+1.)
            s["additions"]+=1
        end
    end
    s["previous"]=method===nothing ? nothing : (method=method,view=view,source=source)
    s["last_us"]=now
end
function project_repetition!(s,candidates)
    applied=false
    for c in candidates
        h=get(s["nodes"],c["method"],0.)
        if h>=4.
            c["priority"]-=min(4.,h/4.)
            applied=true
        end
    end
    s["projections"]+=Int(applied)
    applied
end
