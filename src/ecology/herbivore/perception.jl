# Lazy grass regeneration is owned by the world. Observations contain values,
# never a reference to the world's mutable storage.
function observe_state!(w,a,i,t,threat)
    k=cell(w,a.x[i],a.z[i]); localgrass=grass!(w,k,t)
    danger=threat!==nothing && hypot(a.x[i]-threat[1],a.z[i]-threat[2])<10 && clear(w,(a.x[i],a.z[i]),threat)
    vegetation=w.traits===nothing && w.layers===nothing ? nothing : configured_rabbit_layer_observation(observe_grass!(w,k,t),a.energy[i])
    (vegetation=vegetation,cell=k,old=a.state[i],energy=a.energy[i],gut=a.gut[i],sleepy=a.sleepy[i],grass=w.layers===nothing ? localgrass : vegetation.food,threat=danger)
end

function observe_neighbors!(w,a,i,t;radius=1)
    k=cell(w,a.x[i],a.z[i]); ix=mod(k-1,w.nx)+1; iz=div(k-1,w.nx)+1
    offsets=radius==1 ? OFFSETS : [(dx,dz) for dx in -radius:radius for dz in -radius:radius if dx!=0 || dz!=0]
    map(offsets) do offset
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
        (vegetation=vegetation,cell=j,grass=w.layers===nothing ? grass : vegetation.food,distance=hypot(p[1]-a.x[i],p[2]-a.z[i]),direction=direction)
    end
end

