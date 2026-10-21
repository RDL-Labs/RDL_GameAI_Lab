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
