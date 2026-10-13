# World-side local height and landing sensor; policy receives no obstacle identity.
function climb_sample(w,a,yaw,index,low,high,resistance_at)
    p=w.positions[a];b=w.bodies[a];theta=deg2rad(yaw+ANGLES[index+1])
    distance=1-b.damage;q=(p[1]+sin(theta)*distance,p[2]+cos(theta)*distance)
    circles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in low]
    touched=[o.height for (o,c) in zip(low,circles) if segment_hit(p,q,c,.2)]
    height=isempty(touched) ? 0. : maximum(touched)
    capacity=.6*(1-b.damage)/(1+.1*w.inventory[a])
    landing=!any(c->segment_hit(q,q,c,.2),w.obstacles)
    clear=height>0 && height<=capacity+1e-12 && landing && !any(c->segment_hit(p,q,c,.2),high)
    resistance=resistance_at(((p[1]+q[1])/2,(p[2]+q[2])/2))
    _,status,d,delta=step(b,"climb",w.inventory[a],resistance,clear)
    D("direction"=>index,"action"=>"climb","height"=>height,"capacity"=>capacity,
      "landing_clear"=>landing,"clear"=>clear,"load"=>w.inventory[a],"resistance"=>resistance,
      "status"=>status,"cost"=>status=="performed" ? -delta["reserve"] : nothing,
      "distance"=>d,"expected_delta"=>delta)
end

function climb_candidates(samples,movement,target,loop)
    target===nothing && loop.H<loop.threshold && return Any[]
    out=Any[]
    for row in samples
        row["cost"]===nothing && continue
        i=row["direction"]
        movement["energy"]["rows"][i+1]["cost"]===nothing || continue
        angle=deg2rad(Float64(ANGLES[i+1]))
        alignment=target===nothing ? 0. : cos(atan(target["right"],target["forward"])-angle)
        push!(out,D("method"=>"climb_$(ANGLES[i+1])","action"=>"climb","direction"=>i,
          "priority"=>(target===nothing ? 1.5 : 3.+alignment)-.1*row["resistance"]*(1+.1*row["load"]),
          "question"=>target===nothing ? "target_observed" : "target_nearer"))
    end
    out
end
