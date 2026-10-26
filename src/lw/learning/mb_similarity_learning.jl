# Bounded online metric learning from comparable, actually executed transitions.
# Teacher uses the fixed endpoint criterion, never the learned metric or goal reward.
mb_metric_state(enabled=true)=D("enabled"=>enabled,"weights"=>[2.,1.],"updates"=>0,"positive"=>0,"negative"=>0,"skipped"=>0,"examples"=>Any[],"records"=>Any[])
function mb_metric_update!(m,parts,target,source)
    m["enabled"] || return
    isempty(parts) && return
    all(x->all(isfinite,x) && all(>=(0),x),parts) || error("metric features")
    target in (0.,1.) || error("metric target")
    all(x->iszero(x[1]) && iszero(x[2]),parts) && return
    weights=m["weights"];before=copy(weights)
    scores=[exp(-weights[1]*x[1]-weights[2]*x[2]) for x in parts]
    prediction=sum(scores)/length(scores)
    for j in 1:2
        gradient=(prediction-target)*sum(scores[i]*parts[i][j] for i in eachindex(parts))/length(parts)
        weights[j]=clamp(weights[j]+.05gradient,.25,4.)
    end
    m["updates"]+=1;m[target==1 ? "positive" : "negative"]+=1
    push!(m["records"],D("source"=>source,"target"=>target,"prediction"=>prediction,"before"=>before,"after"=>copy(weights)))
    length(m["records"])>64 && popfirst!(m["records"])
end
function mb_metric_observe!(s,receipt,frame,now)
    m=s["recognition"]["metric"];m["enabled"] || return
    (receipt===nothing || frame===nothing || receipt["status"]!="performed" || now!=receipt["now"]+1_000_000 || !(receipt["action"] in ("walk","scan"))) && return
    origin=get(s["nodes"],receipt["from"],nothing);origin===nothing && return
    from=(signature=origin["signature"],anchor=0.)
    context=(receipt["action"],round(Int,receipt["offset"]/15),round(Int,receipt["distance"]*10),receipt["goal"])
    compared=0
    for previous in Iterators.reverse(m["examples"])
        previous["context"]==context || continue
        compared>=8 && break;compared+=1
        a=get(s["nodes"],previous["from"],nothing);b=get(s["nodes"],previous["to"],nothing)
        (a===nothing || b===nothing) && continue
        start=mb_similarity(from,a);finish=mb_similarity(frame,b)
        if start===nothing || finish===nothing || start.common<2 || finish.common<2
            m["skipped"]+=1;continue
        end
        target=finish.agreement>=.85 ? 1. : finish.agreement<=.65 ? 0. : nothing
        if target===nothing;m["skipped"]+=1;continue;end
        mb_metric_update!(m,start.parts,target,"op:$(receipt["now"]):$(s["actor"])")
    end
    push!(m["examples"],D("context"=>context,"from"=>receipt["from"],"to"=>frame.key))
    length(m["examples"])>64 && popfirst!(m["examples"])
end
