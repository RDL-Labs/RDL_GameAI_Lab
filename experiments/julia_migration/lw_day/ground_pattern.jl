# Fifteen actor-relative samples; no map, road identity or destination authority.
function ground_appearance(w,a,yaw,g,now;dry=p->true)
    p=w.positions[a];cells=Any[]
    for angle in ANGLES, distance in (1,2,4)
        sn,cs=sincos(deg2rad(yaw[a]+angle));q=(p[1]+sn*distance,p[2]+cs*distance)
        blocked=any(o->segment_hit(p,q,o,0.),w.obstacles)
        c=blocked ? nothing : wear_cell!(g,(floor(Int,q[1]),floor(Int,q[2])))
        wear=c===nothing ? 0. : c["wear"]
        push!(cells,D("angle"=>angle,"distance"=>distance,"status"=>blocked ? "occluded" : "sampled",
            "appearance"=>blocked ? nothing : !dry(q) ? "water" : wear>=10 ? "bare_ground" : wear>0 ? "trampled_grass" : "grass"))
    end
    D("source"=>D("actor"=>a,"observation"=>"ob:$now:$a","capture_us"=>now),
      "coverage"=>any(c->c["status"]=="occluded",cells) ? "partial" : "complete","cells"=>cells)
end
function ground_neighbors(i)
    a,d=divrem(i-1,3)
    [aa*3+dd+1 for (aa,dd) in ((a-1,d),(a+1,d),(a,d-1),(a,d+1)) if 0<=aa<5 && 0<=dd<3]
end
function ground_patterns(v)
    cells=v["cells"];length(cells)==15 || error("ground_sample_budget")
    remaining=Set(i for i in 1:15 if cells[i]["status"]=="sampled");groups=Any[]
    while !isempty(remaining)
        firstid=minimum(remaining);appearance=cells[firstid]["appearance"]
        component=Set([firstid]);todo=[firstid];delete!(remaining,firstid)
        while !isempty(todo)
            i=pop!(todo)
            for j in ground_neighbors(i)
                if j in remaining && cells[j]["appearance"]==appearance
                    delete!(remaining,j);push!(component,j);push!(todo,j)
                end
            end
        end
        ids=sort(collect(component))
        points=[(cells[i]["distance"]*sind(cells[i]["angle"]),cells[i]["distance"]*cosd(cells[i]["angle"])) for i in ids]
        n=length(points);mx=sum(p[1] for p in points)/n;mz=sum(p[2] for p in points)/n
        xx=sum((p[1]-mx)^2 for p in points)/n;zz=sum((p[2]-mz)^2 for p in points)/n
        xz=sum((p[1]-mx)*(p[2]-mz) for p in points)/n
        disc=sqrt((xx-zz)^2+4*xz*xz);major=(xx+zz+disc)/2;minor=max(0.,(xx+zz-disc)/2)
        band=n>=3 && major>0 && major>=4*minor
        unknown=sort(unique([j-1 for i in ids for j in ground_neighbors(i) if cells[j]["status"]=="occluded"]))
        push!(groups,D("pattern_ref"=>v["source"]["observation"]*":ground:$(firstid-1)",
            "appearance"=>appearance,"sample_indices"=>ids.-1,
            "sample_links"=>[[i-1,j-1] for i in ids for j in ground_neighbors(i) if j in component && i<j],
            "shape"=>band ? "sampled_band_candidate" : n>=3 ? "sampled_patch" : "insufficient_shape",
            "angular_extent"=>[minimum(cells[i]["angle"] for i in ids),maximum(cells[i]["angle"] for i in ids)],
            "distance_extent"=>[minimum(cells[i]["distance"] for i in ids),maximum(cells[i]["distance"] for i in ids)],
            "unknown_neighbor_indices"=>unknown,"touches_sampling_boundary"=>any(i->div(i-1,3) in (0,4) || mod(i-1,3) in (0,2),ids),
            "continuity"=>"between_samples_unverified"))
    end
    D("source"=>copy(v["source"]),"coverage"=>v["coverage"],"status"=>isempty(groups) ? "unavailable" : "patterns_available",
      "groups"=>groups,"authority"=>"descriptive sampled grouping; no road identity or action authority")
end
function record_ground_patterns!(s,v,patterns=ground_patterns(v))
    s["observations"]+=1
    for g in patterns["groups"]
        key=g["appearance"]*":"*g["shape"]
        s["counts"][key]=get(s["counts"],key,0)+1
    end
    push!(s["records"],D("observation"=>v,"patterns"=>patterns))
    length(s["records"])>16 && popfirst!(s["records"])
end
