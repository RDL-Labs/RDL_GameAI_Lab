function material(phase,x,z)
    river=12+5sin((z-6)/22+phase); width=1.2+.4*(1+sin(z/13)); d=abs(x-river)
    d<=width/2 && return WATER
    d<4 && return BANK
    (((x+28)/18)^2+((z-28)/24)^2<1 || ((x-37)/17)^2+((z+20)/25)^2<1) && return FOREST
    ((x+23)/13)^2+((z+25)/15)^2<1 && return ROCK
    GRASSLAND
end
cell(w,x,z)=clamp(floor(Int,(x-w.xmin)/w.cellsize)+1,1,w.nx)+(clamp(floor(Int,(z-w.zmin)/w.cellsize)+1,1,w.nz)-1)*w.nx
center(w,k)=(w.xmin+(mod(k-1,w.nx)+.5)*w.cellsize,w.zmin+(div(k-1,w.nx)+.5)*w.cellsize)
function clear(w,p,q)
    w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25 || return false
    material(w.phase,q...)!=WATER && material(w.phase,(p[1]+q[1])/2,(p[2]+q[2])/2)!=WATER || return false
    !any(o->RDLMigrationProbe.segment_hit(p,q,o,.25),w.obstacles)
end
function build(spec; seed=20261005, grass_scale=1.)
    s=spec.scene; land=s.landscape; xmin,xmax,zmin,zmax=Float64.(land.extent)
    nx=round(Int,(xmax-xmin)/2); nz=round(Int,(zmax-zmin)/2); n=nx*nz
    objects=[RDLMigrationProbe.Circle(Float64(o.x),Float64(o.z),Float64(o.radius)) for o in vcat(collect(s.obstacles),collect(s.low_obstacles)) if !hasproperty(o,:solid) || o.solid]
    w=World(xmin,zmin,xmax,zmax,2.,nx,nz,land.phase,zeros(UInt8,n),falses(n),zeros(n),zeros(n),zeros(Int,n),objects,0.,0.,0.)
    rng=MersenneTwister(seed)
    for k in 1:n
        p=center(w,k); m=material(w.phase,p...); w.material[k]=m
        w.walkable[k]=m!=WATER && !any(o->hypot(p[1]-o.x,p[2]-o.z)<=o.radius+.25,objects)
        cap=m==GRASSLAND ? 6. : m==BANK ? 5. : m==FOREST ? 2. : 0.
        w.capacity[k]=w.walkable[k] ? grass_scale*cap*(.75+.5rand(rng)) : 0.
    end
    w.grass.=w.capacity; w.initial=sum(w.grass)
    n=length(s.positions)
    a=Animals([Float64(p[1]) for p in s.positions],[Float64(p[2]) for p in s.positions],2pi.*rand(rng,n),fill(70.,n),zeros(n),[.5*(i-1)/max(n-1,1) for i in 1:n],fill(SEARCH,n),zeros(Int32,n),zeros(Int32,n),zeros(Int32,n),zeros(Int,n),zeros(n),zeros(n),zeros(n),zeros(Int,n),zeros(Int,n),zeros(Int,n,5))
    for i in 1:n
        clear(w,(a.x[i],a.z[i]),(a.x[i],a.z[i])) || error("original spawn is not traversable")
        a.current_cell[i]=cell(w,a.x[i],a.z[i])
    end
    w,a
end
function grass!(w,k,t)
    # Lazy linear regeneration is exactly the same regardless of observation count.
    elapsed=t-w.updated[k]; elapsed>=0 || error("time reversal")
    add=min(w.capacity[k]-w.grass[k],w.capacity[k]*elapsed/(2*17280))
    w.grass[k]+=add; w.grown+=add; w.updated[k]=t
    w.grass[k]
end
