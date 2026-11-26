# World geometry, not a configured action or a learned home relation.
# Units: world distance (native human scale: 1 = 10 m). Open shelters for now:
# roofs are visible, but walls/doors do not yet obstruct movement or sound.
const PERSONAL_HOUSE_DEFAULTS = (radius=0.6, height=0.4, clearance=0.4,
    spacing=2.0, common_radius=2.0, max_rings=32)

function personal_houses(spec, actor_ids)
    get(spec,:personal_houses,false) || return NamedTuple[]
    owners=String.(collect(actor_ids))
    length(unique(owners))==length(owners) || error("duplicate house owner")
    settings=get(spec,:personal_house_settings,(;))
    p=PERSONAL_HOUSE_DEFAULTS
    radius=Float64(get(settings,:radius,p.radius))
    height=Float64(get(settings,:height,p.height))
    clearance=Float64(get(settings,:clearance,p.clearance))
    spacing=Float64(get(settings,:spacing,p.spacing))
    common_radius=Float64(get(settings,:common_radius,p.common_radius))
    max_rings=get(settings,:max_rings,p.max_rings)
    all(isfinite,(radius,height,clearance,spacing,common_radius)) &&
        radius>0 && height>0 && clearance>=0 && common_radius>=0 &&
        spacing>=2radius+clearance || error("invalid personal house geometry")
    max_rings isa Integer && 0<max_rings<=1024 || error("invalid personal house search limit")
    camp=Float64.(spec.home)
    length(camp)==2 && all(isfinite,camp) || error("invalid house camp")
    land=get(spec,:landscape,nothing)
    obstacles=vcat(collect(spec.obstacles),collect(get(spec,:low_obstacles,Any[])),
        collect(get(spec,:food_facilities,Any[])),collect(get(spec,:visual_landmarks,Any[])))
    houses=NamedTuple[]
    isempty(owners) && return houses
    # Stable expanding square rings: adding actors does not move earlier houses.
    for ring in 1:max_rings, iz in -ring:ring, ix in -ring:ring
        max(abs(ix),abs(iz))==ring || continue
        x,z=camp[1]+ix*spacing,camp[2]+iz*spacing
        hypot(x-camp[1],z-camp[2])>=common_radius+radius+clearance || continue
        any(o->hypot(x-o.x,z-o.z)<radius+clearance+get(o,:radius,0.),obstacles) && continue
        any(f->hypot(x-f.x,z-f.z)<radius+clearance,spec.food) && continue
        if land!==nothing
            extent=get(land,:extent,(-Inf,Inf,-Inf,Inf))
            extent[1]<=x-radius && x+radius<=extent[2] &&
                extent[3]<=z-radius && z+radius<=extent[4] || continue
            # Riparian water occupies a continuous x interval at each z.
            # Sample across the footprint, conservatively include the clearance.
            dry=all(-1:0.25:1) do dz
                zz=z+dz*(radius+clearance)
                abs(x-river_x(land.phase,zz))>radius+clearance+river_width(zz)/2
            end
            dry || continue
        end
        owner=owners[length(houses)+1]
        norm=hypot(x-camp[1],z-camp[2])
        entrance=(x+(camp[1]-x)*radius/norm,z+(camp[2]-z)*radius/norm)
        push!(houses,(id="house:"*owner,owner=owner,x=x,z=z,radius=radius,height=height,
            entrance=entrance,rest_position=(x,z),storage_owner=owner))
        length(houses)==length(owners) && return houses
    end
    error("personal house placement exhausted: $(length(houses))/$(length(owners)); enlarge camp/map or search limit")
end

personal_house_visuals(houses)=[(x=h.x,z=h.z,radius=h.radius,height=h.height,
    color="brown",solid=false,light_source=0.) for h in houses]
personal_house_for(houses,owner)=findfirst(h->h.owner==owner,houses)
function personal_house_presence(houses,owner,position)
    index=personal_house_for(houses,owner)
    index===nothing && return nothing
    house=houses[index]
    (id=house.id,inside=hypot(position[1]-house.x,position[2]-house.z)<=house.radius)
end
