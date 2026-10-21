# Local observed-target refinement; full walk effort is retained for short steps.
near_target(t)=t!==nothing && 1.25<t["distance"]<=16.
function refine_approach!(plan,target,w,a,yaw,resistance_at)
    near_target(target) && plan["action"]=="walk" || return false
    angle=rad2deg(atan(target["right"],target["forward"]))
    coarse=ANGLES[plan["direction"]+1]
    abs(angle-coarse)<=22.5+1e-9 || return false # refine the chosen sector, not a different method
    span=min(.5*(1-w.bodies[a].damage),max(0.,target["distance"]-1.))
    theta=deg2rad(yaw[a]+angle);s,c=sincos(theta);p=w.positions[a]
    q=(p[1]+s*span,p[2]+c*span)
    clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
    resistance=resistance_at(((p[1]+q[1])/2,(p[2]+q[2])/2))
    _,status,_,_=step(w.bodies[a],"walk",w.inventory[a],resistance,clear)
    status=="performed" || return false
    plan["approach_angle"]=angle;plan["approach_span"]=span
    true
end
