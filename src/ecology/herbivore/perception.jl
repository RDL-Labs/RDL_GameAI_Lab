# Lazy grass regeneration is owned by the world. Observations contain values,
# never a reference to the world's mutable storage.
function observe_state!(w,a,i,t,threat)
    k=cell(w,a.x[i],a.z[i]); localgrass=grass!(w,k,t)
    danger=threat!==nothing && hypot(a.x[i]-threat[1],a.z[i]-threat[2])<10 && clear(w,(a.x[i],a.z[i]),threat)
    (cell=k,old=a.state[i],energy=a.energy[i],gut=a.gut[i],sleepy=a.sleepy[i],grass=localgrass,threat=danger)
end

function observe_neighbors!(w,a,i,t)
    k=cell(w,a.x[i],a.z[i]); ix=mod(k-1,w.nx)+1; iz=div(k-1,w.nx)+1
    map(OFFSETS) do offset
        dx,dz=offset
        jx,jz=ix+dx,iz+dz
        1<=jx<=w.nx && 1<=jz<=w.nz || return nothing
        j=jx+(jz-1)*w.nx
        w.walkable[j] || return nothing
        p=center(w,j)
        clear(w,(a.x[i],a.z[i]),p) || return nothing
        direction=atan(p[2]-a.z[i],p[1]-a.x[i])
        grass=grass!(w,j,t)
        (cell=j,grass=grass,distance=hypot(p[1]-a.x[i],p[2]-a.z[i]),direction=direction)
    end
end
