# Shared physical commit for searching, fleeing and grazing micro-movement.
function rabbit_land_step!(w,a,i,q)
    origin=(a.x[i],a.z[i])
    clear(w,origin,q) || return false
    a.x[i],a.z[i]=q;a.distance[i]+=hypot(q[1]-origin[1],q[2]-origin[2])
    next=cell(w,q...)
    if next!=a.current_cell[i];a.previous_cell[i]=a.current_cell[i];a.current_cell[i]=next;end
    true
end
