# Finite adapter: World trajectory stays in the sensor; policy sees relative features only.
function hazard_observation(w,a,yaw,hazards,sec)
    features=Any[];p=w.positions[a];s,c=sincos(deg2rad(yaw[a]))
    for h in hazards
        h.start<=sec<h.stop || continue
        q=(Float64(h.x+h.vx*(sec-h.start)),Float64(h.z+h.vz*(sec-h.start)))
        dx,dz=q[1]-p[1],q[2]-p[2];f,r=dx*s+dz*c,dx*c-dz*s;d=hypot(dx,dz)
        if d<=12 && f>=0 && !any(o->segment_hit(p,q,o,0.),w.obstacles)
            push!(features,D("forward"=>f,"right"=>r,"distance"=>d))
        end
    end
    D("coverage"=>"complete","features"=>features)
end

safety_state()=D("active"=>false,"H"=>0,"threshold"=>8,"entries"=>0,"releases"=>0,"overrides"=>0)
function safety_plan!(s,ob,movement)
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
        rows=filter(r->away(r)>0,rows)
        if !isempty(rows)
            r=rows[argmax(away.(rows))]
            return D("action"=>"walk","direction"=>parse(Int,r["ref"]),"safety"=>true)
        end
    end
    D("action"=>"scan","safety"=>true)
end
