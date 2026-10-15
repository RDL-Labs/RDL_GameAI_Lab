# World-owned fixed responses; no hidden target/territory in agent observations.
function dynamic_hazards()
 D("last_us"=>nothing,"territory"=>D("position"=>(-20.,-14.),"home"=>(-20.,-14.),"center"=>(-20.,-2.),"mode"=>"idle","target"=>nothing),
   "patrol"=>D("position"=>(-12.,-8.),"heading"=>0),"counts"=>D(),"records"=>Any[])
end
function territory_step!(t,positions,dt,objects)
 home=t["home"];p=t["position"];center=t["center"]
 inside=Dict(a=>q for (a,q) in positions if hypot(q[1]-center[1],q[2]-center[2])<=8)
 target=t["target"];mode=t["mode"]
 if mode=="returning" || (target!==nothing && !haskey(inside,target))
    mode="returning";target=nothing;goal=home
 else
    if target===nothing && !isempty(inside)
        target=first(sort(collect(keys(inside)),by=a->(hypot(inside[a][1]-p[1],inside[a][2]-p[2]),a)))
    end
    if target===nothing
        mode="idle";goal=home
    elseif hypot(p[1]-home[1],p[2]-home[2])>=12
        mode="returning";target=nothing;goal=home
    else
        goal=inside[target];mode=hypot(goal[1]-p[1],goal[2]-p[2])<=3 ? "warning" : "approaching"
    end
 end
 blocked=false
 if mode in ("approaching","returning")
    dx,dz=goal[1]-p[1],goal[2]-p[2];distance=hypot(dx,dz)
    travel=min(2*dt,max(0.,distance-(mode=="approaching" ? 3 : 0)))
    q=distance==0 ? p : (p[1]+dx*travel/distance,p[2]+dz*travel/distance)
    if mode=="approaching" && hypot(q[1]-home[1],q[2]-home[2])>12
        mode="returning";target=nothing
    elseif travel>0 && any(o->segment_hit(p,q,o,.5),objects)
        blocked=true
    else
        t["position"]=q
    end
    mode=="returning" && hypot(t["position"][1]-home[1],t["position"][2]-home[2])<1e-8 && (mode="idle")
 end
 t["mode"]=mode;t["target"]=target;blocked
end
function advance_hazards!(s,now,positions,objects;patrol=true)
 prior=s["last_us"];prior!==nothing && now<prior && error("hazard_clock")
 prior==now && return
 # World moves in reference 250ms substeps; agents remain at their last actual pose.
 times=prior===nothing ? [now] : collect(prior+250_000:250_000:now)
 prior!==nothing && mod(now-prior,250_000)!=0 && error("hazard_step")
 for t in times
    dt=prior===nothing ? 0. : .25
    blocked=territory_step!(s["territory"],positions,dt,objects)
    mode=s["territory"]["mode"];s["counts"][mode]=get(s["counts"],mode,0)+1
    if patrol
        b=s["patrol"];p=b["position"]
        prior!==nothing && div(t,12_000_000)!=div(t-250_000,12_000_000) && (b["heading"]=mod(b["heading"]+90,360))
        q=(p[1]+1.5*dt*cosd(b["heading"]),p[2]+1.5*dt*sind(b["heading"]))
        if dt>0 && any(o->segment_hit(p,q,o,.5),objects)
            b["heading"]=mod(b["heading"]+90,360)
        else
            b["position"]=q
        end
    end
    push!(s["records"],D("us"=>t,"mode"=>mode,"blocked"=>blocked,"position"=>collect(s["territory"]["position"])))
    length(s["records"])>32 && popfirst!(s["records"])
 end
 s["last_us"]=now
end
function dynamic_hazard_sources(s,sec;patrol=true)
 bodies=patrol ? [s["territory"],s["patrol"]] : [s["territory"]]
 [(x=b["position"][1],z=b["position"][2],vx=0.,vz=0.,start=sec,stop=sec+1) for b in bodies]
end
