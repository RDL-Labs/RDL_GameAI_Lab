# Finite adapter: World trajectory stays in the sensor; policy sees relative features only.
function hazard_observation(w,a,yaw,hazards,sec;visual_obstacles=w.obstacles,safe_home=nothing)
    features=Any[];p=w.positions[a];s,c=sincos(deg2rad(yaw[a]))
    for h in hazards
        h.start<=sec<h.stop || continue
        q=(Float64(h.x+h.vx*(sec-h.start)),Float64(h.z+h.vz*(sec-h.start)))
        dx,dz=q[1]-p[1],q[2]-p[2];f,r=dx*s+dz*c,dx*c-dz*s;d=hypot(dx,dz)
        if d<=12 && f>=0 && !any(o->segment_hit(p,q,o,0.),visual_obstacles)
            push!(features,D("forward"=>f,"right"=>r,"distance"=>d))
        end
    end
    safe=safe_home!==nothing && hypot(p[1]-safe_home[1],p[2]-safe_home[2])<=1.25
    safe ? D("coverage"=>"complete","features"=>Any[],"safe_zone"=>true,"observed_hazards"=>features) : D("coverage"=>"complete","features"=>features)
end

safety_state()=D("active"=>false,"H"=>0,"threshold"=>8,"entries"=>0,"releases"=>0,"overrides"=>0)
function safety_plan!(s,ob,movement;running=false)
    if get(ob,"safe_zone",false)
        release_safe_zone!(s);return nothing
    end
    features=ob["features"]
    if !isempty(features)
        !s["active"] && (s["entries"]+=1)
        s["active"]=true;s["H"]=0
    elseif s["active"]
        s["H"]=min(s["threshold"],s["H"]+(ob["coverage"]=="complete" ? 2 : 1))
        if s["H"]>=s["threshold"]
            s["active"]=false;s["releases"]+=1
            return nothing # provisional release, not proof of safety
        end
    end
    s["active"] || return nothing
    s["overrides"]+=1
    if !isempty(features)
        h=features[argmin([f["distance"] for f in features])]
        rows=[r for r in movement["energy"]["rows"] if r["cost"]!==nothing]
        # Only observed feasible directions that increase separation are retreat candidates.
        away(r)=begin
            angle=deg2rad(ANGLES[parse(Int,r["ref"])+1])
            -(h["forward"]*cos(angle)+h["right"]*sin(angle))
        end
        running && append!(rows,[r for r in movement["run_rows"] if r["cost"]!==nothing])
        rows=filter(r->away(r)>0,rows)
        if !isempty(rows)
            score(r)=running ? away(r)/max(h["distance"],.001)*(get(r,"action","walk")=="run" ? r["distance"] : .5) - .05*r["resistance"]*(1+.1*r["load"])*(get(r,"action","walk")=="run" ? 5 : 1) : away(r)
            r=rows[argmax(score.(rows))]
            return D("action"=>get(r,"action","walk"),"direction"=>parse(Int,r["ref"]),"safety"=>true)
        end
    end
    D("action"=>"scan","safety"=>true)
end

# Explicit world protection, not an inference from missing hazards.
function release_safe_zone!(s)
    s["active"] && (s["releases"]+=1)
    s["active"]=false;s["H"]=0;s["clear_yaw"]=0.;s["far_count"]=0
    s["accepted"]=false;s["body_result"]=nothing;s["release_reason"]="camp_safe_zone"
end
