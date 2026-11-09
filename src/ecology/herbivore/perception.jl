# Lazy grass regeneration is owned by the world. Observations contain values,
# never a reference to the world's mutable storage.
const RABBIT_NEIGHBOR_REFERENCE_DISTANCE=2. # legacy cell-center offset in world units
const RABBIT_FINE_OFFSETS=Tuple((dx,dz) for dx in -2:2 for dz in -2:2 if dx!=0 || dz!=0)
rabbit_neighbor_offsets(w)=w.cellsize==1. ? RABBIT_FINE_OFFSETS : OFFSETS
rabbit_neighbor_radius(w)=w.cellsize==1. ? 2 : 1
# Scores use grass per legacy 4 square units, not the smaller cell's total stock.
rabbit_grass_score_scale(w)=(RABBIT_NEIGHBOR_REFERENCE_DISTANCE/w.cellsize)^2
function observe_state!(w,a,i,t,threat)
    k=cell(w,a.x[i],a.z[i]); localgrass=grass!(w,k,t)
    danger=threat!==nothing && hypot(a.x[i]-threat[1],a.z[i]-threat[2])<10 && clear(w,(a.x[i],a.z[i]),threat)
    vegetation=w.traits===nothing && w.layers===nothing ? nothing : configured_rabbit_layer_observation(observe_grass!(w,k,t),a.energy[i])
    (vegetation=vegetation,cell=k,old=a.state[i],energy=a.energy[i],gut=a.gut[i],sleepy=a.sleepy[i],grass=(w.layers===nothing ? localgrass : vegetation.food)*rabbit_grass_score_scale(w),threat=danger)
end

function observe_neighbors!(w,a,i,t)
    k=cell(w,a.x[i],a.z[i]); ix=mod(k-1,w.nx)+1; iz=div(k-1,w.nx)+1
    map(rabbit_neighbor_offsets(w)) do offset
        dx,dz=offset
        jx,jz=ix+dx,iz+dz
        1<=jx<=w.nx && 1<=jz<=w.nz || return nothing
        j=jx+(jz-1)*w.nx
        w.walkable[j] || return nothing
        p=center(w,j)
        rabbit_neighbor_clear(w,a,i,j,t,(a.x[i],a.z[i]),p) || return nothing
        direction=atan(p[2]-a.z[i],p[1]-a.x[i])
        grass=grass!(w,j,t)
        vegetation=w.traits===nothing && w.layers===nothing ? nothing : configured_rabbit_layer_observation(observe_grass!(w,j,t),a.energy[i])
        (vegetation=vegetation,cell=j,grass=(w.layers===nothing ? grass : vegetation.food)*rabbit_grass_score_scale(w),distance=hypot(p[1]-a.x[i],p[2]-a.z[i]),direction=direction)
    end
end
