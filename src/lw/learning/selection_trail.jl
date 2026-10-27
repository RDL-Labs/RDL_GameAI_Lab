# Actual-use trails, ported from runtime/selection_trail.py.
selection_trail_state(actor)=D("actor"=>actor,"edges"=>D(),"episode"=>nothing,"completed"=>Any[],"cursor"=>nothing,"changes"=>0)
trail_key(s,context,phase,c)=JSON3.write(Any[s["actor"]*":food-sufficiency",context,phase,c["method"],Any[c["action"],get(c,"direction",nothing),get(c,"scan_angle",nothing)]])
trail_key_prefix(s,context,phase)=chop(JSON3.write(Any[s["actor"]*":food-sufficiency",context,phase]);tail=1)*","
function trail_key_from_prefix(prefix,c)
 suffix=JSON3.write(Any[c["method"],Any[c["action"],get(c,"direction",nothing),get(c,"scan_angle",nothing)]])
 prefix*SubString(suffix,2)
end
function project_trails!(s,candidates,loop,context,phase)
 phase in ("exploration","return") || return nothing
 baseline=method_choice(loop,candidates)["method"];edges=D();prefix=nothing
 for c in candidates
    get(c,"record_trial",true) || continue
    # Context is identical for all candidates in this projection; keep exact JSON keys.
    prefix===nothing && (prefix=trail_key_prefix(s,context,phase))
    key=trail_key_from_prefix(prefix,c);e=get(s["edges"],key,D())
    c["priority"]+=min(1.,get(e,"uses",0)*.02)+min(1.,get(e,"success_credit",0.)*.125)
    edges[c["method"]]=key
 end
 selected=method_choice(loop,candidates)["method"]
 D("edges"=>edges,"selected"=>selected,"changed"=>baseline!=selected)
end
function use_trail!(s,actor,op,trace,method,status,reserve,H,refs)
 actor==s["actor"] || error("trail_binding")
 op==s["cursor"] && return false
 s["cursor"]=op
 trace===nothing && return false
 haskey(trace["edges"],method) && !(status in ("stale","expired","unexecuted")) || return false
 key=trace["edges"][method]
 if !haskey(s["edges"],key) && length(s["edges"])>=512
    s["capacity_reached"]=true;return false
 end
 e=get!(s["edges"],key,D("uses"=>0,"success_credit"=>0.,"successes"=>0))
 e["uses"]+=1;e["last_operation"]=op
 trace["changed"] && method==trace["selected"] && (s["changes"]+=1)
 if reserve<=80
    s["episode"]===nothing && (s["episode"]=D("start"=>op,"edges"=>D(),"max_H"=>0))
    ep=s["episode"];ep["max_H"]=max(ep["max_H"],H)
    entry=get!(ep["edges"],key,D("first_operation"=>op,"uses"=>0,"bundle_refs"=>String[]))
    entry["uses"]+=1;entry["bundle_refs"]=sort(unique(vcat(entry["bundle_refs"],refs)))
 end
 true
end
function resolve_trail!(s,actor,reserve,source,now)
 actor==s["actor"] || error("trail_binding")
 ep=s["episode"];(ep===nothing || reserve<=80) && return false
 total=1+min(8,ep["max_H"]);share=total/length(ep["edges"])
 for key in keys(ep["edges"])
    e=s["edges"][key];e["successes"]+=1;e["success_credit"]=min(8.,e["success_credit"]+share)
 end
 ep["confirmed_by"]=source;ep["confirmed_us"]=now;ep["credit"]=total
 push!(s["completed"],ep);s["episode"]=nothing;true
end
