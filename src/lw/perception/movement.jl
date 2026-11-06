function perceive_movement(w,actor,yaw,food,stock;resistance_at=p->1.5,run_resistance_at=resistance_at,running=false,visual_obstacles=w.obstacles,known_food_sites=())
    origin=w.positions[actor];s,c=sincos(deg2rad(yaw[actor]));visible=Any[];empty_sites=Int[]
    for (j,f) in enumerate(food)
        fishing=get(f,:acquisition,"pickup")=="fishing"
        dx,dz=f.x-origin[1],f.z-origin[2];forward,right=dx*s+dz*c,dx*c-dz*s
        distance=hypot(forward,right)
        if !fishing && stock[j]==0 && j-1 in known_food_sites && distance<=1.25 && forward>=0 && !any(o->segment_hit(origin,(Float64(f.x),Float64(f.z)),o,0.),visual_obstacles)
            push!(empty_sites,j-1)
        end
        if (fishing || stock[j]>0) && distance<=12 && forward>=0 && !any(o->segment_hit(origin,(Float64(f.x),Float64(f.z)),o,0.),visual_obstacles)
            push!(visible,D("ref"=>j-1,"forward"=>forward,"right"=>right,"distance"=>distance,
                "appearance"=>hasproperty(f,:appearance) ? f.appearance : "brown_capped_ovoid","condition"=>get(f,:condition,0)))
            fishing && (last(visible)["acquisition"]="fishing")
        end
    end
    coverage=length(visible)>5 ? "partial" : "complete"
    sort!(visible,by=v->(v["distance"],v["ref"]));resize!(visible,min(5,length(visible)))
    b=w.bodies[actor];surface=Any[];walks=NamedTuple[];runs=NamedTuple[]
    for (j,angle) in enumerate(ANGLES)
        theta=deg2rad(yaw[actor]+angle);endpoint=(origin[1]+sin(theta),origin[2]+cos(theta))
        clear=!any(o->segment_hit(origin,endpoint,o,.2),w.obstacles)
        push!(surface,D("direction_deg"=>angle,"status"=>clear ? "sampled" : "blocked",
            "height_delta"=>clear ? 0. : nothing))
        midpoint=(origin[1]+sin(theta)*.25*(1-b.damage),origin[2]+cos(theta)*.25*(1-b.damage))
        push!(walks,(ref=string(j-1),angle=angle,clear=clear,resistance=resistance_at(midpoint)))
    end
    if running
        for (j,angle) in enumerate(ANGLES)
            theta=deg2rad(yaw[actor]+angle);distance=1.5*(1-b.damage)
            endpoint=(origin[1]+sin(theta)*distance,origin[2]+cos(theta)*distance)
            midpoint=((origin[1]+endpoint[1])/2,(origin[2]+endpoint[2])/2)
            clear=!any(o->segment_hit(origin,endpoint,o,.2),w.obstacles)
            push!(runs,(ref=string(j-1),clear=clear,resistance=run_resistance_at(midpoint)))
        end
    end
    (body=b,load=w.inventory[actor],visible=visible,empty_sites=empty_sites,coverage=coverage,surface=surface,walks=walks,runs=runs)
end
