# Observer-neutral, bounded decision evidence. Never feeds selection or consumes RNG.
function gradient_capture!(relation,loop,candidates,chosen,source,now;channel="social",probabilities=nothing)
    relation===nothing && return nothing
    get(relation,"gradient_logging",true) || return nothing
    log=get!(()->D("records"=>Any[],"captured"=>0,"evicted"=>0,"unmatched_results"=>0),relation,"gradient_maps")
    any(r->r["source"]==source,log["records"]) && return source
    probs=probabilities===nothing ? method_distribution(loop,candidates) : probabilities
    index=findfirst(c->c["method"]==chosen["method"],candidates)
    index===nothing && error("gradient_selected_candidate_missing")
    order=sortperm(probs;rev=true);keep=order[1:min(15,length(order))]
    index in keep || push!(keep,index)
    rows=Any[]
    for i in keep
        c=candidates[i];node=loop===nothing ? nothing : get(loop.methods,c["method"],nothing)
        learned=node===nothing ? 0. : log1p(node.reward)
        repulsion=node===nothing ? 0. : failure_repulsion(node)
        method_H=node===nothing ? 0. : min(2.,node.H/node.threshold)
        temperature=loop===nothing || get(c,"goal_arrival",false) ? 1. : 1+loop.H/loop.threshold
        row=D("method"=>c["method"],"base"=>c["priority"],"learned"=>learned,
            "repulsion"=>repulsion,"method_penalty"=>method_H,"temperature"=>temperature,
            "prior"=>get(c,"observation_log_prior",0.),"probability"=>probs[i],"feasible"=>get(c,"feasible",true),
            "log_weight"=>(c["priority"]+learned-repulsion-method_H)/temperature+get(c,"observation_log_prior",0.))
        for k in ("action","target","partner","expected","trade_gain","trade_expected_gain","context","trade_context","observed_context","terms","components")
            haskey(c,k) && (row[k]=deepcopy(c[k]))
        end
        trace=get(c,"trace",get(c,"gradient_relation",nothing))
        if trace!==nothing
            row["relation_weight"]=get(trace,"weight",0.)
            predictions=get(get(trace,"profile",D()),"predictions",D())
            row["MB"]=D(string(k)=>D("ids"=>copy(get(v,"mb_ids",String[])),
                "probability"=>get(v,"probability",nothing),"matches"=>deepcopy(get(v,"matches",Any[]))) for (k,v) in pairs(predictions))
        end
        push!(rows,row)
    end
    # Freeze only relevant owner state, not the complete memory or another's private state.
    sec=food_security(relation)
    state=sec===nothing ? nothing : D(k=>deepcopy(get(sec,k,nothing)) for k in ("H","required","shortfall","estimate"))
    push!(log["records"],D("source"=>source,"us"=>now,"channel"=>channel,"selected"=>chosen["method"],
        "probabilities_supplied"=>probabilities!==nothing,"H"=>loop===nothing ? nothing : loop.H,"candidates"=>rows,"candidate_count"=>length(candidates),
        "omitted_probability"=>max(0.,1-sum(probs[keep])),"owner_forecast"=>state,
        "observation"=>deepcopy(get(relation,"social_view",nothing)),"outcomes"=>Any[]))
    log["captured"]+=1
    length(log["records"])>64 && (popfirst!(log["records"]);log["evicted"]+=1)
    source
end
function gradient_result!(relation,source,status;actual=nothing,now=nothing)
    (relation===nothing || source===nothing || !get(relation,"gradient_logging",true)) && return false
    log=get(relation,"gradient_maps",nothing);log===nothing && return false
    i=findfirst(r->r["source"]==source,log["records"])
    if i===nothing;log["unmatched_results"]+=1;return false;end
    outcomes=log["records"][i]["outcomes"]
    result=D("status"=>status,"actual"=>actual,"us"=>now)
    result in outcomes && return false
    push!(outcomes,result);length(outcomes)>4 && popfirst!(outcomes)
    true
end
