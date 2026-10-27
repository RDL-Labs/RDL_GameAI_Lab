include("mb_similarity_learning.jl")
# Shared uncertain correspondence. Raw observation keys remain distinct records.
mb_recognition_state()=D("metric"=>mb_metric_state(),"associations"=>D(),"rejections"=>D(),"feedback"=>Any[],"selected"=>0,"matches"=>0,"mismatches"=>0,"execution_failures"=>0,"unknown"=>0,"admission_blocked"=>0,"sleep_reviews"=>Any[])
function mb_reject!(s,scope,reason)
    key=scope*":"*reason;r=s["recognition"]["rejections"];r[key]=get(r,key,0)+1
    nothing
end
function mb_features(signature)
    out=D()
    for part in split(signature,'|')
        x=split(part,':');length(x)==3 || continue
        out[x[1]]=(band=x[2],angle=30parse(Int,x[3]))
    end
    out
end
function mb_similarity(frame,node;metric=nothing)
    observed=hasproperty(frame,:features) ? frame.features : mb_features(frame.signature)
    memory=get!(() -> mb_features(node["signature"]),node,"features")
    common=sort(collect(intersect(keys(observed),keys(memory))))
    isempty(common) && return nothing
    anchor=first(common);shift=wrap_angle(observed[anchor].angle-memory[anchor].angle)
    bands=D("near"=>0,"mid"=>1,"far"=>2)
    parts=[(Float64(abs(get(bands,observed[k].band,3)-get(bands,memory[k].band,3))),abs(wrap_angle(observed[k].angle-memory[k].angle-shift))/30) for k in common]
    weights=metric===nothing || !metric["enabled"] ? (2.,1.) : metric["weights"]
    agreement=sum(exp(-weights[1]*x[1]-weights[2]*x[2]) for x in parts)/length(parts)
    # Missing features are unknown, not contradictions. One feature is weak evidence.
    confidence=agreement*min(1.,length(common)/2)
    (parts=parts,confidence=confidence,agreement=agreement,common=length(common),anchor=wrap_angle(frame.anchor+shift))
end
# Experimental tolerance1, quadratic scale2. Floor avoids ceil's immediate 1->2 jump.
mb_retrieval_width(H)=min(136.,1+(max(0.,clamp(Float64(H),0.,32.)-1)/2)^2)
mb_retrieval_budget(H)=floor(Int,mb_retrieval_width(H))
function mb_correspondences(s,targets,now;scope="wake",H=0)
    frame=s["current"];out=Any[]
    frame===nothing && (mb_reject!(s,scope,"no_observation");return out)
    # Cheap retrieval order, not a declaration of identity. Full geometry is evaluated lazily.
    observed=hasproperty(frame,:features) ? frame.features : mb_features(frame.signature)
    ranked=Tuple{Float64,String,Float64}[]
    for key in sort(unique(collect(targets)))
        node=get(s["nodes"],key,nothing);node===nothing && continue
        id=frame.key*":"*key
        a=get(s["recognition"]["associations"],id,nothing)
        support=a===nothing ? .5 : (1+a["matches"])/(2+a["matches"]+a["mismatches"])
        features=get!(() -> mb_features(node["signature"]),node,"features")
        common=count(k->haskey(features,k),keys(observed))
        common==0 && continue
        push!(ranked,(support*min(1.,common/2),key,support))
    end
    sort!(ranked,by=x->(-x[1],x[2]))
    # Wider pressure opens weaker relations. Inadequate fit also opens the next batch.
    batch=mb_retrieval_budget(H)
    examined=0;best_weight=0.;batches=0
    for (_,key,support) in ranked
        if examined>0 && examined%batch==0
            best_weight>=.25 && break
        end
        examined%batch==0 && (batches+=1)
        examined+=1
        node=s["nodes"][key]
        fit=mb_similarity(frame,node;metric=s["recognition"]["metric"]);fit===nothing && continue
        id=frame.key*":"*key
        weight=max(1e-6,fit.confidence*support)
        best_weight=max(best_weight,weight)
        push!(out,D("key"=>key,"association"=>id,"confidence"=>fit.confidence,"weight"=>weight,"anchor"=>fit.anchor))
    end
    stats=get!(s["recognition"],"retrieval") do
        D("calls"=>0,"eligible"=>0,"examined"=>0,"expanded"=>0,"records"=>Any[])
    end
    stats["calls"]+=1;stats["eligible"]+=length(ranked);stats["examined"]+=examined
    stats["expanded"]+=max(0,batches-1)
    push!(stats["records"],D("us"=>now,"scope"=>scope,"H"=>H,"width"=>mb_retrieval_width(H),"batch"=>batch,
        "eligible"=>length(ranked),"examined"=>examined,"batches"=>batches,"best_weight"=>best_weight))
    length(stats["records"])>32 && popfirst!(stats["records"])
    sort!(out,by=x->(-x["weight"],x["key"]))
    limit=min(8,examined);length(out)>limit && resize!(out,limit)
    isempty(out) && (mb_reject!(s,scope,"no_shared_features");return out)
    total=sum(x["weight"] for x in out)
    for x in out;x["probability"]=x["weight"]/total;end
    out
end
function mb_attach_correspondence!(p,s,match)
    p["mb_association"]=match["association"];p["mb_recognized"]=match["key"]
    p["mb_observed"]=s["current"].key;p["mb_recognition_probability"]=match["probability"]
    p["mb_recognition_confidence"]=match["confidence"]
    # BasicLoop samples these joint recognition/action alternatives; this is not a location oracle.
    p["priority"]+=log(max(1e-6,2match["weight"]))
    p
end
function mb_prediction_outcome(s,receipt,frame,now)
    now==receipt["now"]+1_000_000 || return "unknown"
    receipt["status"]=="performed" || return "execution_failure"
    key=receipt["predicted"]
    (frame===nothing || key===nothing || !haskey(s["edges"],key)) && return "unknown"
    node=get(s["nodes"],s["edges"][key]["to"],nothing);node===nothing && return "unknown"
    fit=mb_similarity(frame,node)
    (fit===nothing || fit.common<2) && return "unknown"
    fit.agreement>=.85 ? "match" : fit.agreement<=.65 ? "mismatch" : "unknown"
end
function mb_recognition_feedback!(s,receipt,frame,now)
    id=get(receipt,"association",nothing);id===nothing && return
    r=s["recognition"];outcome=mb_prediction_outcome(s,receipt,frame,now)
    a=get(r["associations"],id,nothing)
    if a===nothing && length(r["associations"])<2048
        a=D("matches"=>0,"mismatches"=>0,"execution_failures"=>0,"unknown"=>0,"uses"=>0)
        r["associations"][id]=a
    end
    field=outcome=="match" ? "matches" : outcome=="mismatch" ? "mismatches" : outcome=="execution_failure" ? "execution_failures" : "unknown"
    r[field]+=1
    if a!==nothing;a[field]+=1;a["uses"]+=1;else;r["admission_blocked"]+=1;end
    push!(r["feedback"],D("source"=>"op:$(receipt["now"]):$(s["actor"])","association"=>id,
        "edge"=>receipt["predicted"],"outcome"=>outcome,"cause"=>outcome=="mismatch" ? "recognition_or_transition_unresolved" : outcome))
    length(r["feedback"])>64 && popfirst!(r["feedback"])
end

# Capacity is a storage bound, not a time-to-live. Waking records stop growing at the bound.
function mb_sleep_organize!(s,day,now)
    r=s["recognition"];any(x->x["day"]==day,r["sleep_reviews"]) && return
    before=(nodes=length(s["nodes"]),edges=length(s["edges"]),chunks=length(s["chunks"]),associations=length(r["associations"]))
    if length(s["edges"])>=.9MB_MAP_EDGE_LIMIT
        ordered=sort(collect(keys(s["edges"])),by=k->(s["edges"][k]["samples"]+s["edges"][k]["matches"]-s["edges"][k]["misses"],k))
        for k in Iterators.take(ordered,length(ordered)-floor(Int,.75MB_MAP_EDGE_LIMIT));delete!(s["edges"],k);s["evictions"]+=1;end
    end
    if length(s["nodes"])>=.9MB_MAP_NODE_LIMIT
        degree=D();for e in values(s["edges"]),k in (e["from"],e["to"]);degree[k]=get(degree,k,0)+1;end
        ordered=sort(collect(keys(s["nodes"])),by=k->(get(degree,k,0)+10Int(s["nodes"][k]["home"]||s["nodes"][k]["food"]),k))
        for k in Iterators.take(ordered,length(ordered)-floor(Int,.75MB_MAP_NODE_LIMIT));mb_forget_node!(s,k);end
    end
    if length(s["chunks"])>=MB_CHUNK_LIMIT
        ordered=sort(collect(keys(s["chunks"])),by=k->(s["chunks"][k]["successes"]+s["chunks"][k]["matches"]-s["chunks"][k]["misses"],k))
        for k in Iterators.take(ordered,16);delete!(s["chunks"],k);end
    end
    if length(r["associations"])>=2048
        ordered=sort(collect(keys(r["associations"])),by=k->(r["associations"][k]["matches"]-r["associations"][k]["mismatches"],r["associations"][k]["uses"],k))
        for k in Iterators.take(ordered,512);delete!(r["associations"],k);end
    end
    mb_prune_chunks!(s)
    filter!(p->all(k->haskey(s["edges"],k),p.second["edges"]),s["sleep"]["hypotheses"])
    push!(r["sleep_reviews"],D("day"=>day,"us"=>now,"before"=>before,"nodes"=>length(s["nodes"]),"edges"=>length(s["edges"])))
end
