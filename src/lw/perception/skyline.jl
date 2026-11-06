# Per-World immutable geometry values; only the sensory adapter consumes these.
# Objects are static in the current LW. A future geometry mutation must rebuild.
prepare_skyline_objects(objects) = [(x=Float64(o.x),z=Float64(o.z),
    radius=Float64(o.radius),height=Float64(o.height),color=String(o.color)) for o in objects]

# Python LW World.cast / finite-elevated-fan-v1, bounded current sensory evidence.
function skyline_fan(objects,position,yaw,source;subrays=false)
    features=Any[];best=fill(Inf,3,13);hits=zeros(Int,3,13)
    for (ai,angle) in enumerate(-90:15:90)
        for delta in (subrays ? (-5,0,5) : (0,))
            -90<=angle+delta<=90 || continue
            sn,cs=sincos(deg2rad(yaw+angle+delta))
            for (oi,o) in enumerate(objects)
                d=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
                (d===nothing || d>48) && continue
                for (ei,elevation) in enumerate((0,15,30))
                    if 1+d*tand(elevation)<=o.height && d<best[ei,ai]
                        best[ei,ai]=d;hits[ei,ai]=oi
                    end
                end
            end
        end
    end
    for (ei,elevation) in enumerate((0,15,30)), (ai,angle) in enumerate(-90:15:90)
        oi=hits[ei,ai];oi==0 && continue
        hit=objects[oi];distance=best[ei,ai]
        push!(features,D("ref"=>"ray:$elevation:$angle","color"=>String(hit.color),
            "azimuth"=>[max(-90,angle-7.5),min(90,angle+7.5)],"elevation"=>elevation,
            "range_band"=>distance<=8 ? "near" : distance<=24 ? "mid" : "far",
            "distance"=>distance<=8 ? 4. : distance<=24 ? 16. : 36.,"distance_estimated"=>true))
    end
    D("model"=>"finite-elevated-fan-v1","source"=>source,"coverage"=>"complete","features"=>features)
end
skyline_state()=D("home_memory"=>nothing,"observations"=>0,"selections"=>0,"records"=>Any[])
function record_skyline!(s,view)
    get(view,"coverage","")=="predicted" && return
    if s["observations"]==0 && view["coverage"]=="complete"
        colors=unique([f["color"] for f in view["features"] if f["range_band"]=="near" && f["elevation"]>=15])
        length(colors)==1 && (s["home_memory"]=D("color"=>only(colors),"source"=>view["source"]))
    end
    s["observations"]+=1;push!(s["records"],view)
    length(s["records"])>16 && popfirst!(s["records"])
end
function skyline_home_candidates(s,view,movement)
    s["home_memory"]===nothing && return Any[]
    ps=landmark_patches(get(view,"coverage","")=="predicted" ? merge(view,D("coverage"=>"complete")) : view,s["home_memory"]["color"])
    (ps===nothing || length(ps)!=1) && return Any[]
    angle=only(ps)["angle"]
    rows=[r for r in movement["energy"]["rows"] if r["cost"]!==nothing]
    isempty(rows) && return Any[]
    sort!(rows,by=r->(abs(ANGLES[parse(Int,r["ref"])+1]-angle),r["cost"],r["ref"]))
    [D("method"=>"skyline_home","action"=>"walk","direction"=>parse(Int,first(rows)["ref"]),
       "priority"=>4.,"question"=>"movement_progress","observation_source"=>view["source"],
       "cue_kind"=>"sky","cue_label"=>s["home_memory"]["color"],"cue_angle"=>angle,
       "cue_distance"=>only(ps)["distance"],"cue_tier"=>1,"cue_uncertain"=>true,"cue_source"=>view["source"],"steering_angle"=>angle)]
end

# Short-lived sensory prediction, not a new confirmed observation. Checkpointed
# inside skyline_state; geometry and hidden object identities never enter cache.
function predicted_skyline!(sample,s,receipt,now,source;fine=false,enabled=false)
    c=get!(s,"prediction",D("view"=>nothing,"sample_us"=>-1,"last_us"=>-1,
        "travel"=>0.,"fresh"=>0,"reused"=>0,"reason"=>"initial"))
    v=c["view"]
    step=receipt===nothing ? 0. : hypot(receipt["forward"],receipt["right"])
    turn=receipt===nothing ? 0. : mod(Float64(receipt["yaw"])+180,360)-180
    reason=!enabled ? "disabled" : v===nothing ? "initial" : fine ? "fine" :
        receipt===nothing || get(receipt,"after_us",-1)!=now || c["last_us"]!=now-1_000_000 ? "gap" :
        step<.001 ? "stationary_or_blocked" : abs(turn)>5 ? "turn" :
        now-c["sample_us"]>=4_000_000 ? "age" : c["travel"]+step>.5 ? "travel" :
        any(f->f["range_band"]=="near",v["features"]) ? "near" : "reuse"
    c["last_us"]=now;c["reason"]=reason
    if reason!="reuse"
        v=sample();c["view"]=v;c["sample_us"]=now;c["travel"]=0.;c["fresh"]+=1
        return v
    end
    fs=Any[]
    for f in v["features"]
        # Distance bands give an estimate, not hidden exact geometry.
        d=f["range_band"]=="mid" ? 16. : 36.
        lo,hi=f["azimuth"];angle=(lo+hi)/2
        right=d*sind(angle)-receipt["right"];forward=d*cosd(angle)-receipt["forward"]
        predicted=rad2deg(atan(right,forward))-turn
        width=(hi-lo)/2
        abs(predicted)+width<=90 || continue
        push!(fs,merge(f,D("azimuth"=>[predicted-width,predicted+width])))
    end
    result=merge(v,D("source"=>source,"coverage"=>"predicted","features"=>fs,
        "observed_us"=>c["sample_us"],"prediction_age_us"=>now-c["sample_us"]))
    c["view"]=result;c["travel"]+=step;c["reused"]+=1
    result
end

# Adaptive observation schedule. Retained predictions guide action but are not
# additional sensory evidence. Counters and scheduling state are checkpointed.
function interval_skyline!(sample,s,receipt,now,source;enabled=false,
        distance=Inf,uncertain=true,pressure=0.,context="",fine=false)
    c=get!(s,"interval_observation",D("view"=>nothing,"sample_us"=>-1,"last_us"=>-1,
        "interval"=>1.,"speed"=>0.,"pressure"=>pressure,"context"=>context,
        "fresh"=>0,"skipped"=>0,"reasons"=>D(),"interval_sum"=>0.,"max_interval"=>1.))
    v=c["view"];step=receipt===nothing ? 0. : hypot(receipt["forward"],receipt["right"])
    turn=receipt===nothing ? 0. : mod(Float64(receipt["yaw"])+180,360)-180
    gap=receipt===nothing || get(receipt,"after_us",-1)!=now || c["last_us"]!=now-1_000_000
    pressure_rise=pressure>c["pressure"]+1e-6
    stalled=c["speed"]>.01 && step<.001
    c["speed"]=max(step,.8c["speed"])
    # A quarter of time-to-contact, using current observations/estimates only.
    eta_limit=isfinite(distance) ? max(1.,.25max(0.,distance-.75)/max(.01,c["speed"])) : 16.
    limit=min(16.,eta_limit,uncertain ? 2. : 16.,fine ? 2. : 16.)
    reason=!enabled ? "disabled" : v===nothing ? "initial" : gap ? "gap" :
        context!=c["context"] ? "goal_change" : pressure_rise ? "forecast_residual" :
        stalled ? "stalled" : abs(turn)>15 ? "turn" :
        (now-c["sample_us"])/1e6>=min(c["interval"],limit) ? "due" : "skip"
    c["last_us"]=now;c["context"]=context;c["pressure"]=pressure
    reasons=c["reasons"];reasons[reason]=get(reasons,reason,0)+1
    if reason!="skip"
        fresh=sample()
        signature(view)=Set((f["color"],f["elevation"],f["range_band"]) for f in view["features"])
        agrees=v!==nothing && signature(v)==signature(fresh)
        c["interval"]=reason=="due" && agrees ? min(16.,2c["interval"]) : 1.
        c["view"]=fresh;c["sample_us"]=now;c["fresh"]+=1
        return fresh
    end
    # Advance bearings only as a prediction, using coarse depth bands. This is
    # not ray casting and cannot certify visibility, arrival, or absence.
    fs=Any[]
    for f in v["features"]
        d=get(f,"predicted_distance",f["range_band"]=="near" ? 4. : f["range_band"]=="mid" ? 16. : 36.)
        lo,hi=f["azimuth"];angle=(lo+hi)/2
        x=d*sind(angle)-receipt["right"];z=d*cosd(angle)-receipt["forward"]
        angle=rad2deg(atan(x,z))-turn;width=(hi-lo)/2
        abs(angle)+width<=90 || continue
        push!(fs,merge(f,D("azimuth"=>[angle-width,angle+width],"predicted_distance"=>hypot(x,z))))
    end
    result=merge(v,D("source"=>source,"coverage"=>"predicted","features"=>fs,
        "observed_us"=>c["sample_us"],"prediction_age_us"=>now-c["sample_us"]))
    c["view"]=result;c["skipped"]+=1;c["interval_sum"]+=min(c["interval"],limit)
    c["max_interval"]=max(c["max_interval"],min(c["interval"],limit))
    result
end

function skyline_schedule_inputs(m,landmarks,movement,home)
    active=get(get(m,"daily_plan",D()),"active",nothing)
    goal=active===nothing ? "" : get(active,"choice","")
    distances=Float64[]
    if landmarks!==nothing
        for f in landmarks["features"]
            d=get(f,"distance",nothing);d===nothing || push!(distances,Float64(d))
        end
    end
    for f in movement["visible"];push!(distances,Float64(f["distance"]));end
    home!==nothing && push!(distances,Float64(home["distance"]))
    estimate=get(m,"home_distance",D())
    if goal=="home" && get(estimate,"known",false)
        push!(distances,max(0.,hypot(estimate["forward"],estimate["right"])-estimate["uncertainty"]))
    end
    (distance=minimum(distances;init=Inf),uncertain=isempty(distances),
        pressure=Float64(get(get(m,"parent_mb",D()),"H_requested",0.)),context=String(goal))
end
