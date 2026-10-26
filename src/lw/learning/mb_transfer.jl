# Whitelist learned state; never resume physical state or an unfinished trial.
function mb_transfer!(fresh,old,ended_us)
    check(fresh["actor"]==old["actor"],"transfer_actor")
    for key in ("nodes","edges","chunks")
        fresh[key]=deepcopy(old[key])
    end
    for n in values(fresh["nodes"])
        n["seen"]-=ended_us
        pop!(n,"features",nothing) # Derived NamedTuple cache is rebuilt from signature.
    end
    for c in values(fresh["chunks"])
        haskey(c,"last_success_us") && (c["last_success_us"]-=ended_us)
    end
    fresh["parent_mb"]["models"]=deepcopy(old["parent_mb"]["models"])
    # Old observation identities must not collide with new op:0 identities.
    function namespace!(v)
        if v isa AbstractDict
            for (k,x) in v
                if x isa String && (startswith(x,"op:") || startswith(x,"ob:"))
                    v[k]="previous-world:"*x
                else
                    namespace!(x)
                end
            end
        elseif v isa AbstractVector
            foreach(namespace!,v)
        end
    end
    namespace!(fresh["parent_mb"]["models"])
    for key in ("metric","associations","rejections")
        fresh["recognition"][key]=deepcopy(old["recognition"][key])
    end
    for e in fresh["recognition"]["metric"]["examples"]
        e["context"]=Tuple(e["context"])
    end
    fresh["transfer"]=D("source_ended_us"=>ended_us,"nodes"=>length(fresh["nodes"]),
        "edges"=>length(fresh["edges"]),"chunks"=>length(fresh["chunks"]),"mode"=>"new-world-learned-state-only")
    fresh
end
function mb_transfer_methods!(loop,old)
    for (name,n) in old["methods"]
        loop.methods[name]=MethodNode(0.,Float64(n["threshold"]),0,Float64(n["reward"]),Int(n["failure_count"]),Float64(n["failure_H_total"]))
    end
end
