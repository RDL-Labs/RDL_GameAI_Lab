# World-owned patches; agents receive five local samples, never the patch map.
function ground_resistance(p,patches)
    value=1.5
    for patch in patches
        isfinite(patch.resistance) && patch.resistance>=1.5 || error("ground resistance")
        if hypot(p[1]-patch.x,p[2]-patch.z)<=patch.radius
            value=max(value,Float64(patch.resistance))
        end
    end
    value
end

function ground_candidates(candidates,movement,load)
    out=deepcopy(candidates)
    for c in out
        c["action"]=="walk" || continue
        row=movement["energy"]["rows"][c["direction"]+1]
        row["cost"]===nothing && error("infeasible ground candidate")
        # Reserve effort above the flat-ground baseline, in fixed priority units.
        # No new direction, feasibility, or method identity is introduced.
        c["priority"]-=.25*max(0.,row["resistance"]-1.5)*(1+.1*load)
    end
    out
end
