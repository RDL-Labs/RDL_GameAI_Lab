# Rich ecology adapter. No per-blade state; vegetation observations are value snapshots.
include("../../world_features.jl")
function grass_cover!(w,k,t;body_height=.4)
    body_height>0 || throw(ArgumentError("positive body height required"))
    amount=grass!(w,k,t);fraction=w.capacity[k]>0 ? clamp(amount/w.capacity[k],0.,1.) : 0.
    w.traits===nothing && return fraction
    clamp(w.traits.density[k]*fraction*min(1.,w.traits.height[k]/body_height),0.,1.)
end
function observe_grass!(w,k,t)
    amount=grass!(w,k,t);fraction=w.capacity[k]>0 ? clamp(amount/w.capacity[k],0.,1.) : 0.
    traits=w.traits
    (color=traits===nothing ? UInt8(1) : traits.color[k],width=w.cellsize,
     height=traits===nothing ? .4 : traits.height[k],
     density=(traits===nothing ? 1. : traits.density[k])*fraction,food=amount,
     cover=grass_cover!(w,k,t))
end

"Nearby visible features without persistent world IDs or hidden food stock."
function observe_objects(w,x,z;range=12.)
    out=NamedTuple[]
    for o in w.features
        d=hypot(o.x-x,o.z-z);d<=range || continue
        # The target's own trunk/rock is excluded from its occluders.
        any(c->!(c.x==o.x && c.z==o.z) && RDLMigrationProbe.segment_hit((x,z),(o.x,o.z),c,0.),w.obstacles) && continue
        push!(out,(color=o.color,width=2o.radius,height=o.height,distance=d,bearing=atan(o.z-z,o.x-x)))
    end
    out
end
