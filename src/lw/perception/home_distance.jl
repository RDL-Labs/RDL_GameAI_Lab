# Egocentric estimate from observed home and proprioceptive receipts only.
home_distance_state()=D("known"=>false,"forward"=>0.,"right"=>0.,"uncertainty"=>0.,
    "receipt"=>nothing,"profile"=>"coarse","fine_ticks"=>0,"coarse_ticks"=>0,"anchors"=>0,
    "near"=>false,"checking"=>false,"check_remaining"=>0,"cooldown"=>0,
    "checks"=>0,"confirmed"=>0,"unresolved"=>0,"scan_selected"=>0,"reason"=>"unknown")
function observe_home_distance!(s,home)
    home===nothing && return
    s["known"]=true;s["forward"]=Float64(home["forward"]);s["right"]=Float64(home["right"])
    s["uncertainty"]=.25;s["anchors"]+=1
    if s["checking"]
        s["confirmed"]+=1;s["checking"]=false;s["check_remaining"]=0
        s["cooldown"]=120;s["unresolved"]=0
    end
end
function home_distance_profile!(s,receipt)
    if s["known"] && receipt!==nothing && s["receipt"]!=receipt["operation"]
        f=s["forward"]-receipt["forward"];r=s["right"]-receipt["right"]
        turn=mod(Float64(receipt["yaw"])+180,360)-180
        sn,cs=sincosd(turn)
        s["forward"]=f*cs+r*sn;s["right"]=r*cs-f*sn
        s["uncertainty"]+=.02hypot(receipt["forward"],receipt["right"])+.0005abs(turn)+.0001
        s["receipt"]=receipt["operation"]
    end
    s["cooldown"]=max(0,s["cooldown"]-1)
    if s["checking"] && s["check_remaining"]==0
        s["checking"]=false;s["unresolved"]+=1
        s["cooldown"]=120*2^min(3,s["unresolved"]-1)
    end
    # Uncertainty requests observation; it is not evidence of being far away.
    if (!s["known"] || s["uncertainty"]>3.) && !s["checking"] && s["cooldown"]==0
        s["checking"]=true;s["check_remaining"]=24;s["checks"]+=1
    end
    d=hypot(s["forward"],s["right"])
    s["near"]=s["known"] && d<=(s["near"] ? 12. : 10.)
    s["profile"]=s["near"] || s["checking"] ? "fine" : "coarse"
    s["reason"]=s["checking"] ? "confirm" : s["near"] ? "near" : "far_or_unknown"
    s["checking"] && (s["check_remaining"]-=1)
    s[s["profile"]*"_ticks"]+=1
    s["profile"]
end
function home_distance_candidates(s)
    s["checking"] || return Any[]
    # A normal, learnable candidate, not an override of bodily/safety priorities.
    Any[D("method"=>"home_distance_confirm","action"=>"scan","priority"=>3.,
        "question"=>"target_observed","scan_angle"=>isodd(s["checks"]) ? 60. : -60.,
        "home_distance_confirm"=>true)]
end
