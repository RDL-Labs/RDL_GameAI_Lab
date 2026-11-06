# River stock is stored once, in spatial cells in the ordinary resource ledger.
# Adjacent casting sites draw from overlapping cells, never duplicate pools.
function river_fishing_neighbors(food,j)
    f=food[j];river=get(f,:river_id,nothing)
    river===nothing && return [(j,1.)]
    radius=Float64(get(f,:fishing_radius,6.))
    [(i,max(0.,1-hypot(f.x-g.x,f.z-g.z)/radius)) for (i,g) in enumerate(food)
        if fishing_site(g) && get(g,:river_id,nothing)==river && hypot(f.x-g.x,f.z-g.z)<radius]
end
function river_fishing_field(food,stock,j,effect)
    neighbors=river_fishing_neighbors(food,j)
    capacity=sum(w*food[i].stock for (i,w) in neighbors)
    remaining=sum(w*stock[i] for (i,w) in neighbors)
    fraction=capacity>0 ? clamp(remaining/capacity,0.,1.) : 0.
    base=Float64(get(food[j],:fishing_base_probability,.25))
    (probability=game_river_fishing_probability(base,fraction,effect),fraction=fraction,neighbors=neighbors)
end
function river_fishing_take!(stock,neighbors,rng)
    total=sum(w*stock[i] for (i,w) in neighbors)
    total>0 || return nothing
    u=rand(rng)*total
    fallback=nothing
    for (i,w) in neighbors
        stock[i]>0 && w>0 || continue
        fallback=i;u-=w*stock[i]
        if u<0;stock[i]-=1;return i;end
    end
    stock[fallback]-=1;fallback
end
function validate_river_fishing(food)
    for f in food
        fishing_site(f) || continue
        base=get(f,:fishing_base_probability,.25);radius=get(f,:fishing_radius,6.)
        base isa Real && !(base isa Bool) && isfinite(base) && 0<=base<=1 || error("fishing probability")
        radius isa Real && isfinite(radius) && radius>0 || error("fishing radius")
        f.stock isa Integer && f.stock>=0 || error("fishing capacity")
        river=get(f,:river_id,nothing)
        river===nothing || (river isa AbstractString && !isempty(river)) || error("river identity")
    end
end
