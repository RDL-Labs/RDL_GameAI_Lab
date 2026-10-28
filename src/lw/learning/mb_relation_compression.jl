# Storage approximation only. No World identity, reverse edges, or goal credit.
# Storage tolerance: one adjacent angular band among two shared features.
# Calibrate with the individual's learned metric, rather than treating .65 as
# the same angular tolerance after the learned feature weights change.
mb_compression_tolerance(metric)=.5*(1+exp(-(metric===nothing || !metric["enabled"] ? 1. : metric["weights"][2])))-.02
function mb_relation_compression_fit(views,a,b;metric=nothing)
    a==b && return 1.
    x=get(views,a,nothing);y=get(views,b,nothing)
    (x===nothing || y===nothing) && return 0.
    (x["home"]==y["home"] && x["food"]==y["food"]) || return 0.
    fit=mb_similarity((signature=x["signature"],features=x["features"],anchor=0.),y;metric=metric)
    fit===nothing && return 0.
    coverage=fit.common/max(length(x["features"]),length(y["features"]))
    # Do not merge low-information single-cue scenes merely because one color agrees.
    fit.common>=2 && coverage>=.8 ? fit.agreement : 0.
end
function mb_relation_compression_compatible(a,b,views;metric=nothing)
    a["label"]==b["label"] || return false
    # Keep the representative's prediction, so a sequence of intermediate means
    # cannot silently widen the group across successive sleep reviews.
    all(abs(a[k]-b[k])<=.1 for k in ("origin_home_strength","predicted_strength")) || return false
    all(abs(a[k]-b[k])<=.2 for k in ("approach_evidence","arrival_evidence")) || return false
    support(l)=(1+l["support"])/(2+l["support"]+l["contradiction"]+l["failures"])
    abs(support(a)-support(b))<=.15 || return false
    # An observed consequence and an unknown consequence stay distinct.
    x,y=a["target_scene"],b["target_scene"]
    (x===nothing || y===nothing) && return x===y
    mb_relation_compression_fit(views,x,y;metric=metric)>=mb_compression_tolerance(metric)
end
function mb_compress_exploration!(s,day,now)
    mb_exploration_enabled(s) || return nothing
    r=mb_exploration_state!(s)
    stats=get!(r,"compression") do
        D("last_day"=>-1,"merged"=>0)
    end
    stats["last_day"]>=day && return nothing
    links=r["links"];before=length(links)
    metric=s["recognition"]["metric"]
    needed=Set{String}()
    for l in values(links)
        push!(needed,l["source"])
        l["target_scene"]!==nothing && push!(needed,l["target_scene"])
    end
    views=D()
    for key in needed
        n=get(s["nodes"],key,nothing);n===nothing && continue
        views[key]=D("signature"=>n["signature"],"features"=>mb_features(n["signature"]),
            "home"=>n["home"],"food"=>n["food"])
    end
    pending=get(r,"pending",nothing);protected=pending===nothing ? nothing : pending["link"]
    # Existing groups take precedence; representative geometry is not averaged.
    ordered=sort(collect(keys(links)),by=k->(-get(links[k],"represented",1),k))
    kept=String[];comparisons=0
    for key in ordered
        b=links[key];best=nothing;best_fit=0.
        if key!=protected
            for rep in kept
                rep==protected && continue
                a=links[rep];a["label"]==b["label"] || continue
                comparisons+=1
                fit=mb_relation_compression_fit(views,a["source"],b["source"];metric=metric)
                if fit>=mb_compression_tolerance(metric) && fit>best_fit && mb_relation_compression_compatible(a,b,views;metric=metric)
                    best=rep;best_fit=fit
                end
            end
        end
        if best===nothing
            push!(kept,key);continue
        end
        a=links[best]
        for field in ("support","contradiction","failures","selected")
            a[field]+=b[field]
        end
        a["represented"]=get(a,"represented",1)+get(b,"represented",1)
        delete!(links,key)
    end
    after=length(links)
    record=D("day"=>day,"us"=>now,"before"=>before,"after"=>after,"merged"=>before-after,
        "comparisons"=>comparisons,"missing_source"=>count(l->!haskey(views,l["source"]),values(links)))
    stats["last_day"]=day;stats["merged"]+=before-after
    record
end
