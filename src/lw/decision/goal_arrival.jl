# Provisional goal hypotheses: observation -> approach -> actual completion elsewhere.
# Only egocentric observations/receipts enter; never world positions.
goal_arrival_state()=D("mode"=>"search","target"=>nothing,"estimate"=>home_distance_state(),
    "ticks"=>0,"budget"=>0.,"H"=>0.,"residual"=>0.,"cooldown"=>0,"confidence"=>0.,
    "entries"=>0,"rejections"=>0,"selected"=>0,"records"=>Any[])
function goal_arrival_event!(s,kind,now)
    push!(s["records"],D("kind"=>kind,"us"=>now,"target"=>s["target"],"H"=>s["H"],"confidence"=>s["confidence"]))
    length(s["records"])>64 && popfirst!(s["records"])
end
function goal_arrival_advance!(s,receipt)
    s["cooldown"]=max(0,s["cooldown"]-1)
    s["mode"]=="approach" && home_distance_profile!(s["estimate"],receipt)
end
function goal_arrival_update!(s,observed,id,confidence,now;completed=false)
    if completed
        s["completed"]=get(s,"completed",0)+Int(s["mode"]=="approach")
        s["mode"]=="approach" && goal_arrival_event!(s,"completed_observed",now)
        s["mode"]="search";s["target"]=nothing;return
    end
    if s["mode"]=="search"
        observed!==nothing && confidence>=.75 && s["cooldown"]==0 || return
        s["mode"]="approach";s["target"]=id;s["ticks"]=0;s["H"]=0.;s["residual"]=0.
        s["entries"]+=1
        s["confidence"]=confidence
        s["budget"]=max(60.,4hypot(observed["forward"],observed["right"])/.5+30)
        observe_home_distance!(s["estimate"],observed)
        goal_arrival_event!(s,"entered",now)
    elseif observed!==nothing && id==s["target"]
        e=s["estimate"]
        difference=hypot(e["forward"]-observed["forward"],e["right"]-observed["right"])
        # Small changes are absorbed; contradictory positions accumulate evidence.
        s["H"]+=max(0.,difference-max(1.,e["uncertainty"]))
        observe_home_distance!(e,observed);s["confidence"]=confidence
    end
    if s["H"]>=8.
        goal_arrival_event!(s,"contradicted",now);s["mode"]="search";s["rejections"]+=1;s["cooldown"]=60
    end
end
function goal_arrival_project!(s,candidates,move,family,now)
    s["mode"]=="approach" || return
    s["ticks"]+=1
    residual=max(0.,(s["ticks"]-s["budget"])/30)
    s["H"]+=max(0.,residual-s["residual"]);s["residual"]=residual
    if s["H"]>=8.
        goal_arrival_event!(s,"arrival_overdue",now);s["mode"]="search";s["rejections"]+=1;s["cooldown"]=60;return
    end
    e=s["estimate"];f=e["forward"];r=e["right"];d=hypot(f,r);angle=wrap_angle(atand(r,f))
    direction=argmin(abs.(ANGLES.-angle))-1
    if abs(angle)<=90 && any(x->parse(Int,x["ref"])==direction && x["cost"]!==nothing,move["energy"]["rows"])
        push!(candidates,D("method"=>"goal_arrival:"*family,"action"=>"walk","direction"=>direction,
            "steering_angle"=>angle,"priority"=>3.,"question"=>"target_observed"))
    else
        push!(candidates,D("method"=>"goal_arrival:"*family,"action"=>"scan",
            "scan_angle"=>clamp(angle,-90.,90.),"priority"=>3.,"question"=>"target_observed"))
    end
    strength=8/(1+s["H"]/4) # Pressure broadens local alternatives, not the goal identity.
    for c in candidates
        action=c["action"];alignment=-1.
        if action in ("walk","run")
            bearing=get(c,"steering_angle",Float64(ANGLES[get(c,"direction",0)+1]))
            alignment=strength*(d-hypot(f-.5cosd(bearing),r-.5sind(bearing)))
        elseif action=="scan"
            turn=get(c,"scan_angle",60.)
            alignment=2*(abs(angle)-abs(wrap_angle(angle-turn)))/90-1
        end
        c["goal_arrival"]=true;c["goal_arrival_target"]=s["target"];c["goal_alignment"]=alignment
        c["observation_log_prior"]=get(c,"observation_log_prior",0.)+alignment
    end
end
function goal_arrival_camp_match(place,frame)
    place["complete"] && place["active"] && place["visible"] && frame!==nothing || return 0.
    best=0.
    for n in values(place["members"])
        fit=mb_similarity(frame,n);fit===nothing && continue
        best=max(best,fit.confidence)
    end
    best
end
