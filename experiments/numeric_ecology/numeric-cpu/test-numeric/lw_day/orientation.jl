# Initial ability port from initial_orientation.py; no location or destination.
orientation_state(owner)=D("owner"=>owner,"history"=>Any[],"samples"=>0,"selections"=>0,"left"=>0,"right"=>0,"last"=>nothing)
function sky_sample(owner,source,now,yaw,clock;available=true)
    check(isfinite(yaw),"orientation_yaw")
    center=mod(floor(Int,(-yaw+15)/30)*30+180,360)-180
    D("actor"=>owner,"source"=>source,"capture_us"=>now,"reference"=>"world-fixed-bearing-zero",
      "status"=>available ? "available" : "unavailable","relative_center"=>available ? center : nothing,
      "half_width"=>15,"cue"=>mod(now,clock.day_us)>=clock.phase_boundaries_us[3] ? "stars_equivalent" : "sun_shadow_equivalent",
      "environment"=>"ideal-sky-no-occlusion")
end
function observe_sky!(s,cue)
    check(cue["actor"]==s["owner"],"orientation_owner")
    h=s["history"]
    if !isempty(h)
        check(cue["capture_us"]>=last(h)["capture_us"],"orientation_clock")
        if cue["capture_us"]==last(h)["capture_us"]
            check(cue==last(h),"orientation_conflict");return
        end
    end
    push!(h,copy(cue));length(h)>257 && popfirst!(h) # previous 256 plus current
    s["samples"]+=1
end
function orientation_scan!(s,clock)
    h=s["history"];isempty(h) && return 90
    cue=last(h);cue["status"]=="available" || return 90
    counts=zeros(Int,12);day=div(cue["capture_us"],clock.day_us)
    for r in h
        div(r["capture_us"],clock.day_us)==day && r["status"]=="available" || continue
        counts[div(mod(-r["relative_center"],360),30)+1]+=1
    end
    heading=mod(-cue["relative_center"],360)
    left=counts[div(mod(heading-90,360),30)+1];right=counts[div(mod(heading+90,360),30)+1]
    angle=left<right ? -90 : 90
    s["selections"]+=1;s[angle<0 ? "left" : "right"]+=1
    s["last"]=D("source"=>cue["source"],"counts"=>counts,"turn"=>angle,"reason"=>"least_sampled_heading")
    angle
end
