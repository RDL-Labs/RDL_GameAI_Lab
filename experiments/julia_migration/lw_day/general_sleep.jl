# Finite adaptation of sleep_relation_review.py. Reported relations only.
general_sleep_state()=D("history"=>Any[],"frozen"=>Any[],"formation_us"=>nothing,"reviews"=>Any[])
function freeze_general!(s,owner,now)
    selected=Any[];seen=Set{Tuple{String,String}}()
    for r in reverse(s["history"])
        check(r["actor"]==owner && r["executed_us"]<=now,"general_sleep_source")
        key=(r["action"],r["outcome"]);key in seen && continue
        push!(seen,key);push!(selected,deepcopy(r));length(selected)==6 && break
    end
    s["frozen"]=selected;s["formation_us"]=now
end
function review_general!(s,owner,day,executed)
    any(r->r["day"]==day,s["reviews"]) && return
    records=s["frozen"];pairs=Any[]
    for r in records
        check(r["actor"]==owner && r["executed_us"]<=s["formation_us"]<=executed,"general_sleep_binding")
    end
    for i in 1:length(records),j in i+1:length(records)
        a,b=records[i],records[j];matched=String[];different=String[];missing=String[]
        for key in ("actor","action","outcome","target","context")
            if get(a,key,nothing)===nothing || get(b,key,nothing)===nothing
                push!(missing,key)
            elseif a[key]==b[key]
                push!(matched,key)
            else
                push!(different,key)
            end
        end
        push!(pairs,D("sources"=>[a["id"],b["id"]],"matched"=>matched,"different"=>different,"missing"=>missing))
    end
    push!(s["reviews"],D("day"=>day,"formation_us"=>s["formation_us"],"completed_us"=>executed,
        "records"=>deepcopy(records),"pairs"=>pairs,"status"=>isempty(pairs) ? "insufficient_records" : "compared",
        "authority"=>"reported local relations; no causal inference or model admission"))
end
function remember_general!(s,owner,op,action,status,target,phase,executed;context=nothing,direction=nothing)
    push!(s["history"],D("actor"=>owner,"id"=>op,"action"=>action,"outcome"=>status,
        "context"=>deepcopy(context),"direction"=>direction,"target"=>target,"phase"=>phase,"executed_us"=>executed))
    length(s["history"])>64 && popfirst!(s["history"])
end
