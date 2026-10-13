# Python LW World.cast / finite-elevated-fan-v1, bounded current sensory evidence.
function skyline_fan(objects,position,yaw,source;subrays=false)
    features=Any[]
    for elevation in (0,15,30), angle in -90:15:90
        best=Inf;hit=nothing
        for delta in (subrays ? (-5,0,5) : (0,))
            -90<=angle+delta<=90 || continue
            sn,cs=sincos(deg2rad(yaw+angle+delta))
            for o in objects
                d=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
                if d!==nothing && d<=48 && 1+d*tand(elevation)<=o.height && d<best
                    best=d;hit=o
                end
            end
        end
        hit===nothing && continue
        push!(features,D("ref"=>"ray:$elevation:$angle","color"=>String(hit.color),
            "azimuth"=>[max(-90,angle-7.5),min(90,angle+7.5)],"elevation"=>elevation,
            "range_band"=>best<=8 ? "near" : best<=24 ? "mid" : "far"))
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
