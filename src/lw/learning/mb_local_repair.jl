# Local corrections keep the selected parent route and its frozen estimate.
function mb_route_repair_record!(s,p,status,energy,now)
    get(p,"food_exchange",false) && return
    a=s["routes"]["active"];a===nothing && return
    a["last_us"]=now;mb_route_effort!(a,energy)
    a["repairs"]=get(a,"repairs",0)+1
    r=s["routes"];r["local_repairs"]=get(r,"local_repairs",0)+1
    # Acquisition is still attributed to the real parent goal on the next observation.
    p["action"] in ("pickup","recover","deposit","eat","rest","request") && return
    p["mb_local_repair"]=a["id"]
    a["repair_pending"]=true;a["uncertain"]=true;a["reason"]="local_repair"
    status=="performed" || (a["reason"]="local_repair_blocked")
end
function mb_route_rejoin!(s,frame,now)
    a=s["routes"]["active"]
    (a===nothing || !get(a,"repair_pending",false) || frame===nothing || s["current_us"]!=now) && return
    i=a["cursor"];i>length(a["path"]) && return
    edge=get(s["edges"],a["path"][i],nothing);edge===nothing && return
    fits=Any[]
    for (side,key) in (("from",edge["from"]),("to",edge["to"]))
        node=get(s["nodes"],key,nothing);node===nothing && continue
        fit=mb_similarity(frame,node;metric=s["recognition"]["metric"])
        fit===nothing || fit.agreement<.65 || push!(fits,(side=side,score=fit.confidence))
    end
    isempty(fits) && return
    sort!(fits,by=x->-x.score)
    # Similar-looking endpoints are ambiguous: do not invent progress or jump over the path.
    length(fits)>1 && fits[1].score-fits[2].score<.1 && return
    side=first(fits).side
    side=="to" && (a["cursor"]+=1)
    a["pending_edge"]=nothing;a["repair_pending"]=false;a["uncertain"]=false
    r=s["routes"];r["local_rejoins"]=get(r,"local_rejoins",0)+1
    push!(get!(() -> Any[],r,"repair_records"),D("us"=>now,"id"=>a["id"],"from_index"=>i,"to_index"=>a["cursor"],"side"=>side,"tentative"=>true))
    length(r["repair_records"])>64 && popfirst!(r["repair_records"])
end
