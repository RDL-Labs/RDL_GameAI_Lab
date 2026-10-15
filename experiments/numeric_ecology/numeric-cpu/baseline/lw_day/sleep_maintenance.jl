# Finite per-record adaptation of bundle_sleep.py, not full conjunction bundles.
function maintenance!(s)
    get!(s,"maintenance",D("usage"=>D(),"days"=>Int[],"reviews"=>Any[],"woken"=>0,"last_operation"=>nothing))
end
function review_sleep_usage!(s,day,formation)
    m=maintenance!(s);day in m["days"] && return
    decisions=Any[]
    for id in sort(collect(keys(s["records"])))
        u=m["usage"][id]
        u["formed_us"]>=formation && continue
        u["dormant"] && continue
        u["idle"]=u["uses"]>0 ? 0 : u["idle"]+1
        u["dormant"]=u["uses"]==0 && u["idle"]>=(u["opportunities"]>0 ? 2 : 3)
        push!(decisions,D("source"=>id,"uses"=>u["uses"],"opportunities"=>u["opportunities"],"idle"=>u["idle"],"dormant"=>u["dormant"]))
        u["uses"]=0;u["opportunities"]=0
    end
    push!(m["days"],day);push!(m["reviews"],D("day"=>day,"decisions"=>decisions))
end
function enroll_sleep_usage!(s,now)
    m=maintenance!(s)
    for id in sort(collect(keys(s["records"])))
        haskey(m["usage"],id) && continue
        active=count(u->!u["dormant"],values(m["usage"]))
        m["usage"][id]=D("formed_us"=>now,"uses"=>0,"opportunities"=>0,"idle"=>0,"dormant"=>active>=32)
    end
end
function wake_sleep_usage!(s,context,phase)
    context===nothing && return
    phase in ("exploration","return") || return
    m=maintenance!(s)
    for id in sort(collect(keys(m["usage"])))
        u=m["usage"][id];r=s["records"][id]
        u["dormant"] && get(r,"context",nothing)==context && r["phase"]==phase || continue
        count(x->!x["dormant"],values(m["usage"]))<32 || break
        u["dormant"]=false;u["idle"]=0;m["woken"]+=1
    end
end
function record_sleep_use!(s,plan,op,status)
    haskey(s,"maintenance") || return
    m=s["maintenance"];m["last_operation"]==op && return
    m["last_operation"]=op
    get(plan,"sleep_changed",false) && status in ("performed","blocked") || return
    for id in get(plan,"sleep_sources",String[])
        m["usage"][id]["uses"]+=1
    end
end
