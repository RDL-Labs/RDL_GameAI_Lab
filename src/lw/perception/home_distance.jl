# Egocentric short-term estimate: observed home + existing proprioceptive receipt.
# No world coordinates, true home position, or hidden route is accepted.
home_distance_state()=D("known"=>false,"forward"=>0.,"right"=>0.,"uncertainty"=>0.,
    "receipt"=>nothing,"profile"=>"coarse","fine_ticks"=>0,"coarse_ticks"=>0,"anchors"=>0)
function observe_home_distance!(s,home)
    home===nothing && return
    s["known"]=true;s["forward"]=Float64(home["forward"]);s["right"]=Float64(home["right"])
    s["uncertainty"]=.25;s["anchors"]+=1
end
function home_distance_profile!(s,receipt)
    if s["known"] && receipt!==nothing && s["receipt"]!=receipt["operation"]
        f=s["forward"]-receipt["forward"];r=s["right"]-receipt["right"]
        sn,cs=sincosd(receipt["yaw"])
        s["forward"]=f*cs+r*sn;s["right"]=r*cs-f*sn
        s["uncertainty"]+=.02hypot(receipt["forward"],receipt["right"])+.0005abs(receipt["yaw"])+.0001
        s["receipt"]=receipt["operation"]
    end
    d=hypot(s["forward"],s["right"])
    limit=s["profile"]=="fine" ? 12. : 10.
    s["profile"]=s["known"] && s["uncertainty"]<=3. && d+s["uncertainty"]<=limit ? "fine" : "coarse"
    s[s["profile"]*"_ticks"]+=1
    s["profile"]
end
