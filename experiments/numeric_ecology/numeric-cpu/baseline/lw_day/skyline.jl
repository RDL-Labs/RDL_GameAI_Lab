# Per-World immutable geometry values; only the sensory adapter consumes these.
# Objects are static in the current LW. A future geometry mutation must rebuild.
prepare_skyline_objects(objects) = [(x=Float64(o.x),z=Float64(o.z),
    radius=Float64(o.radius),height=Float64(o.height),color=String(o.color)) for o in objects]

# Python LW World.cast / finite-elevated-fan-v1, bounded current sensory evidence.
function skyline_fan(objects,position,yaw,source;subrays=false)
    features=Any[];best=fill(Inf,3,13);hits=zeros(Int,3,13)
    for (ai,angle) in enumerate(-90:15:90)
        for delta in (subrays ? (-5,0,5) : (0,))
            -90<=angle+delta<=90 || continue
            sn,cs=sincos(deg2rad(yaw+angle+delta))
            for (oi,o) in enumerate(objects)
                d=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
                (d===nothing || d>48) && continue
                for (ei,elevation) in enumerate((0,15,30))
                    if 1+d*tand(elevation)<=o.height && d<best[ei,ai]
                        best[ei,ai]=d;hits[ei,ai]=oi
                    end
                end
            end
        end
    end
    for (ei,elevation) in enumerate((0,15,30)), (ai,angle) in enumerate(-90:15:90)
        oi=hits[ei,ai];oi==0 && continue
        hit=objects[oi];distance=best[ei,ai]
        push!(features,D("ref"=>"ray:$elevation:$angle","color"=>String(hit.color),
            "azimuth"=>[max(-90,angle-7.5),min(90,angle+7.5)],"elevation"=>elevation,
            "range_band"=>distance<=8 ? "near" : distance<=24 ? "mid" : "far"))
    end
    D("model"=>"finite-elevated-fan-v1","source"=>source,"coverage"=>"complete","features"=>features)
end
skyline_state()=D("home_memory"=>nothing,"observations"=>0,"selections"=>0,"records"=>Any[])
function record_skyline!(s,view)
    if s["observations"]==0 && view["coverage"]=="complete"
        colors=unique([f["color"] for f in view["features"] if f["range_band"]=="near" && f["elevation"]>=15])
        length(colors)==1 && (s["home_memory"]=D("color"=>only(colors),"source"=>view["source"]))
    end
    s["observations"]+=1;push!(s["records"],view)
    length(s["records"])>16 && popfirst!(s["records"])
end
function skyline_home_candidates(s,view,movement)
    s["home_memory"]===nothing && return Any[]
    ps=landmark_patches(view,s["home_memory"]["color"])
    (ps===nothing || length(ps)!=1) && return Any[]
    angle=only(ps)["angle"]
    rows=[r for r in movement["energy"]["rows"] if r["cost"]!==nothing]
    isempty(rows) && return Any[]
    sort!(rows,by=r->(abs(ANGLES[parse(Int,r["ref"])+1]-angle),r["cost"],r["ref"]))
    [D("method"=>"skyline_home","action"=>"walk","direction"=>parse(Int,first(rows)["ref"]),
       "priority"=>4.,"question"=>"movement_progress","observation_source"=>view["source"])]
end
