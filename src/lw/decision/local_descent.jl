# Finite local potential descent from observed relative target and obstacle hits.
# No World positions or unobserved target are accepted by this pure evaluator.
function local_descent(target,obstacles)
    target===nothing && return nothing
    obstacles["coverage"]=="complete" && !obstacles["output_limited"] || return nothing
    d=Float64(target["distance"]);d>1.25 || return nothing
    f=Float64(target["forward"])/d;r=Float64(target["right"])/d
    af,ar=f,r
    for o in obstacles["items"]
        q=hypot(o["forward"],o["right"])
        0<q<3 || continue
        strength=2*(1-q/3)^2
        f-=strength*o["forward"]/q;r-=strength*o["right"]/q
    end
    magnitude=hypot(f,r)
    magnitude>1e-8 || return nothing # equilibrium is not an invented direction
    (angle=rad2deg(atan(r,f)),span=min(.5,d-1.),attraction=(af,ar),combined=(f,r))
end

# One local steering field for every selected walk/run. Only current samples
# contribute; no segments are drawn across sampled gaps or unknown intervals.
function structure_descent(angle,obstacles,structures;clearance=2.,water_weight=.35)
    obstacles["coverage"]=="complete" && !obstacles["output_limited"] || return nothing
    ar,af=sind(angle),cosd(angle);rr,rf=0.,0.;groups=0
    supported=structures===nothing || structures["source"]!=get(obstacles,"source",nothing) ? nothing : structures["observation"]
    surfaces=supported===nothing ? [D("kind"=>"obstacle","points"=>[(o["right"],o["forward"])]) for o in obstacles["items"]] :
        [g for g in supported["groups"] if g["kind"] in ("obstacle","water")]
    for g in surfaces
        isempty(g["points"]) && continue
        # One nearest sampled contribution per structure, not one force per ray.
        p=first(sort(g["points"],by=p->(hypot(p...),p[1],p[2])))
        d=hypot(p...);0<d<clearance || continue
        weight=g["kind"]=="water" ? water_weight : 1.
        strength=2*weight*(1-d/clearance)^2
        rr-=strength*p[1]/d;rf-=strength*p[2]/d;groups+=1
    end
    # Soft clearance must not turn an intended advance into retreat by itself.
    backward=rr*ar+rf*af
    if backward<-.8;rr+=(-.8-backward)*ar;rf+=(-.8-backward)*af;end
    r,f=ar+rr,af+rf
    correction=mod(rad2deg(atan(r,f))-angle+180,360)-180
    (angle=angle+clamp(correction,-45.,45.),combined=(f,r),groups=groups)
end

function steer_structure!(plan,target,obstacles,structures,w,a,yaw,resistance_at)
    action=plan["action"];action in ("walk","run") || return false
    # A chosen route/escape retains its own heading even if food/home is visible.
    direct=get(plan,"question",nothing)=="target_nearer" && target!==nothing
    angle=direct ? rad2deg(atan(target["right"],target["forward"])) : get(plan,"steering_angle",Float64(ANGLES[plan["direction"]+1]))
    body=w.bodies[a]
    clearance=2.0 + .05*min(w.inventory[a],6)+.5*body.damage+(action=="run" ? .5 : 0.)
    span=(action=="run" ? 1.5 : .5)*(1-body.damage)
    direct && (span=min(span,max(0.,target["distance"]-1.)))
    span>0 || return false
    map=structures!==nothing && structures["source"]==get(obstacles,"source",nothing) ? structures["observation"] : nothing
    use_rho=map!==nothing && haskey(map,"rho")
    v=use_rho ? rho_descent(angle,map;clearance=clearance,span=span) : structure_descent(angle,obstacles,structures;clearance=clearance)
    v===nothing && return false
    p=w.positions[a];sn,cs=sincosd(yaw[a]+v.angle);q=(p[1]+sn*span,p[2]+cs*span)
    clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
    resistance=resistance_at(((p[1]+q[1])/2,(p[2]+q[2])/2))
    _,status,_,_=step(body,action,w.inventory[a],resistance,clear)
    # Rejected refinements retain the already selected feasible discrete action.
    status=="performed" || return false
    plan["approach_angle"]=v.angle;plan["approach_span"]=span
    plan["field_vector"]=v.combined;plan["structure_groups"]=v.groups
    if use_rho
        plan["rho_profile"]=map["rho"];plan["rho_source"]=map["source"]["observation"]
        plan["potential"]=v.potential
        plan["rho_boundary_range"]=rho_boundary_range(map,clearance)
    end
    true
end
function steer_local_descent!(plan,target,obstacles,w,a,yaw,resistance_at)
    plan["action"]=="walk" && startswith(get(plan,"method",""),"step_") || return false
    v=local_descent(target,obstacles);v===nothing && return false
    p=w.positions[a];s,c=sincos(deg2rad(yaw[a]+v.angle))
    span=min(v.span,.5*(1-w.bodies[a].damage));q=(p[1]+s*span,p[2]+c*span)
    clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
    resistance=resistance_at(((p[1]+q[1])/2,(p[2]+q[2])/2))
    _,status,_,_=step(w.bodies[a],"walk",w.inventory[a],resistance,clear)
    status=="performed" || return false
    plan["approach_angle"]=v.angle;plan["approach_span"]=span
    plan["field_vector"]=v.combined
    true
end
