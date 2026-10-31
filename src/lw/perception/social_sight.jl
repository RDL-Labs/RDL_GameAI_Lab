# World geometry is consumed here only. The decision layer receives a current,
# coarse visual bearing/range and the existing observed peer reference. Identity
# recognition is still an initial ability; this does not infer another's mind.
function social_sight(w,actor,yaw,now;visual_obstacles=w.obstacles,max_distance=12.,half_fov=90.,max_peers=16,expressions=nothing,rho="coarse",attention=nothing)
    check(actor in IDS,"social_sight_actor")
    check(now isa Integer && !(now isa Bool) && now>=0,"social_sight_time")
    heading=yaw isa AbstractDict ? yaw[actor] : yaw
    check(heading isa Real && isfinite(heading),"social_sight_heading")
    check(max_distance isa Real && isfinite(max_distance) && max_distance>0 &&
        half_fov isa Real && isfinite(half_fov) && 0<half_fov<=180 &&
        max_peers isa Integer && !(max_peers isa Bool) && 1<=max_peers<=64,"social_sight_limits")
    p=w.positions[actor];sn,cs=sincosd(heading);peers=Any[]
    for other in IDS
        other==actor && continue
        q=w.positions[other];dx,dz=q[1]-p[1],q[2]-p[2]
        distance=hypot(dx,dz);distance<=max_distance || continue
        forward,right=dx*sn+dz*cs,dx*cs-dz*sn
        angle=distance==0 ? 0. : atand(right,forward)
        abs(angle)<=half_fov || continue
        any(o->segment_hit(p,q,o,0.),visual_obstacles) && continue
        lower,upper=distance<=1.25 ? (0.,1.25) : distance<=2 ? (1.25,2.) :
            distance<=4 ? (2.,4.) : distance<=8 ? (4.,8.) : (8.,Float64(max_distance))
        upper=min(upper,Float64(max_distance))
        # Visible distant appearance is coarse; near attended faces can be refined. Quantized
        # appearance never includes reserve, damage, inventory or cause labels.
        face=if distance<=max_distance
            emitted=expressions===nothing ? configured_expression(w.bodies[other]) : expressions[other]
            resolution=distance<=4 ? (attention==other && rho=="fine" ? 8. : 4.) : 1.
            (calm=round(resolution*emitted.calm)/resolution,
             distress=round(resolution*emitted.distress)/resolution,fear=round(resolution*emitted.fear)/resolution)
        else
            nothing
        end
        push!(peers,D("ref"=>other,"angle"=>clamp(15round(angle/15),-half_fov,half_fov),
            "expression"=>face,
            "range_lower"=>lower,"range_upper"=>upper,"distance"=>(lower+upper)/2,
            "contact"=>distance<=1.25))
    end
    sort!(peers;by=x->(x["distance"],x["ref"]))
    dropped=max(0,length(peers)-max_peers)
    resize!(peers,min(length(peers),max_peers))
    D("actor"=>actor,"source"=>"ob:$now:$actor","capture_us"=>Int(now),
        "coverage"=>dropped==0 ? "complete" : "partial","capacity_dropped"=>dropped,
        "range_limit"=>Float64(max_distance),"half_fov"=>Float64(half_fov),"peers"=>peers)
end
