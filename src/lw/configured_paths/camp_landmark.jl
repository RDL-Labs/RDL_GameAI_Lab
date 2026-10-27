# Removable experiment shortcut: learn a coarse visual signature with observed home.
configured_camp_landmark_state()=D("learned"=>false,"signature"=>nothing,"observations"=>0,
    "paired_home"=>0,"stage"=>1,"stage_views"=>0,"inside_checked"=>false,"outside_checked"=>false,
    "tour_completed"=>false,"offered"=>0,"selected"=>0,"records"=>Any[])
function configured_camp_landmark_view(objects,position,yaw;night=false)
    views=Any[]
    for (i,o) in enumerate(objects)
        # Explicit test signature, not an object ID or a privileged home coordinate.
        o.color=="orange" && o.radius>=1 && o.height>=4 && o.light_source>0 || continue
        dx=o.x-position[1];dz=o.z-position[2];d=hypot(dx,dz)
        0<d<=min(512.,(night ? 144. : 48.)*sqrt(o.light_source)) || continue
        angle=wrap_angle(atand(dx,dz)-yaw);abs(angle)<=90 || continue
        any(enumerate(objects)) do pair
            j,b=pair;j==i && return false;b.height<1 && return false
            hit=RDLMigrationProbe.ray_hit(position,(dx/d,dz/d),RDLMigrationProbe.Circle(b.x,b.z,b.radius))
            hit!==nothing && hit<max(0.,d-o.radius)
        end && continue
        # A visible shape ray is required too: brightness alone cannot identify it.
        shape=false
        for ray in -90:15:90
            sn,cs=sincosd(yaw+ray);best=Inf;idx=0
            for (j,b) in enumerate(objects)
                hit=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(b.x,b.z,b.radius))
                if hit!==nothing && hit<=48 && b.height>=1 && hit<best;best=hit;idx=j;end
            end
            idx==i && (shape=true;break)
        end
        shape || continue
        push!(views,D("signature"=>"orange-large-tall-light","angle"=>angle,"distance"=>d,
            "forward"=>d*cosd(angle),"right"=>d*sind(angle)))
    end
    length(views)==1 ? only(views) : nothing # Ambiguous matching lights do not identify home.
end
function configured_camp_landmark_observe!(s,view,home,observing,now)
    view===nothing && return
    s["observations"]+=1
    if observing && home!==nothing && hypot(view["forward"]-home["forward"],view["right"]-home["right"])<=1.
        s["learned"]=true;s["signature"]=view["signature"];s["paired_home"]+=1
        isempty(s["records"]) && push!(s["records"],D("us"=>now,"kind"=>"observed_home_pair","signature"=>view["signature"]))
    end
end
function configured_camp_landmark_tour!(s,home,position,yaw,sec,view,reserve,strain,local_us,clock)
    (s["tour_completed"] || sec>=1200 || reserve<=0 || strain>=.8 || local_us>=clock.quiet_night_us) && return nothing
    # Explicit scaffolding visits both sides of the known test entrance; never used after day one.
    offsets=(3.,5.5,3.);stage=s["stage"];target=(Float64(home[1]),Float64(home[2])+offsets[stage])
    dx=target[1]-position[1];dz=target[2]-position[2];d=hypot(dx,dz)
    p=D("configured_observation"=>true,"method"=>"configured_camp_landmark_tour")
    if d>.15
        angle=wrap_angle(atand(dx,dz)-yaw)
        abs(angle)>45 && return merge(p,D("action"=>"scan","scan_angle"=>clamp(angle,-90.,90.)))
        return merge(p,D("action"=>"walk","direction"=>argmin(abs.(ANGLES.-angle))-1,"approach_angle"=>angle,"approach_span"=>min(.25,d)))
    end
    if view===nothing || abs(view["angle"])>15
        return merge(p,D("action"=>"scan","scan_angle"=>view===nothing ? 30. : view["angle"]))
    end
    s["stage_views"]+=1
    if s["stage_views"]>=3
        s[stage==2 ? "outside_checked" : "inside_checked"]=true
        push!(s["records"],D("sec"=>sec,"kind"=>"entrance_view","stage"=>stage,"signature"=>view["signature"],"angle"=>view["angle"],"distance"=>view["distance"]))
        s["stage_views"]=0
        stage==3 ? (s["tour_completed"]=true) : (s["stage"]+=1)
    end
    merge(p,D("action"=>"scan","scan_angle"=>0.))
end
function configured_camp_landmark_candidate!(s,view,move)
    s["learned"] && view!==nothing && view["signature"]==s["signature"] || return nothing
    abs(view["angle"])<=90 || return nothing
    direction=argmin(abs.(ANGLES.-view["angle"]))-1
    any(r->parse(Int,r["ref"])==direction && r["cost"]!==nothing,move["energy"]["rows"]) || return nothing
    s["offered"]+=1
    D("method"=>"configured_camp_landmark","action"=>"walk","direction"=>direction,
        "steering_angle"=>view["angle"],"priority"=>6.,"observation_log_prior"=>log(8.),
        "question"=>"target_observed","configured_camp_landmark"=>true)
end
