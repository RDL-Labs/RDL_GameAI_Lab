# 暫定固定の新規実験初期配置。真の草容量/通行可能性を使うが認知へ渡さない。
# 明示呼出しのみON。crossing_longrunの新規配置では既定distributed、legacyで旧20:80。
# 親子同居を優先し、容量比例の区画人数は整数近似。将来は準備期間での分散へ置換。
const RABBIT_DISTRIBUTED_LAYOUT=(seed=20261109,tile_width=16.,bank_margin=3.)
function configured_rabbit_distributed_layout!(s)
    s.ticks==0 || error("distributed layout requires a fresh world")
    w=s.world;a=s.animals;life=s.life;p=RABBIT_DISTRIBUTED_LAYOUT
    rng=Random.Xoshiro(p.seed)
    west(k)=H.center(w,k)[1]<12+5sin((H.center(w,k)[2]-6)/22+w.phase)
    candidates=[k for k in eachindex(w.capacity) if w.walkable[k] && w.capacity[k]>0 &&
        abs(H.center(w,k)[1]-(12+5sin((H.center(w,k)[2]-6)/22+w.phase)))>p.bank_margin]
    isempty(candidates) && error("no suitable grass cells")
    tiles=Dict{Tuple{Int,Int,Bool},Vector{Int}}()
    for k in candidates
        x,z=H.center(w,k)
        key=(floor(Int,(x-w.xmin)/p.tile_width),floor(Int,(z-w.zmin)/p.tile_width),west(k))
        push!(get!(tiles,key,Int[]),k)
    end
    keys_order=sort!(collect(keys(tiles)))
    roots=[i for i in eachindex(s.alive) if s.alive[i] && life.mother[i]==0]
    families=[vcat(i,[j for j in eachindex(s.alive) if s.alive[j] && life.mother[j]==i]) for i in roots]
    sum(length,families)==count(s.alive) || error("unsupported nested or missing family")
    # Large families first; seeded tie order avoids systematic actor-ID placement.
    shuffle!(rng,families);sort!(families;by=length,rev=true,alg=Base.Sort.MergeSort)
    capacity=[sum(w.capacity[k] for k in tiles[key]) for key in keys_order]
    quota=capacity.*(count(s.alive)/sum(capacity));assigned=zeros(Int,length(keys_order))
    selected=Int[]
    for family in families
        available=[j for j in eachindex(keys_order) if !isempty(tiles[keys_order[j]])]
        isempty(available) && error("not enough distinct family locations")
        slot=available[argmax([quota[j]-assigned[j] for j in available])]
        cells=tiles[keys_order[slot]];shuffle!(rng,cells)
        # Spread groups spatially; family members intentionally share their nest.
        k=isempty(selected) ? first(cells) : cells[argmax([minimum(hypot(H.center(w,c)[1]-H.center(w,q)[1],H.center(w,c)[2]-H.center(w,q)[2]) for q in selected) for c in cells])]
        deleteat!(cells,findfirst(==(k),cells));push!(selected,k);assigned[slot]+=length(family)
        position=H.center(w,k)
        for i in family
            a.x[i],a.z[i]=position;a.current_cell[i]=k;a.previous_cell[i]=0;a.target[i]=0;a.next_sense[i]=0
            life.nest[i]=position
        end
    end
    (rule="capacity-weighted-family-dispersion",parameters=p,
     west=count(i->s.alive[i] && west(a.current_cell[i]),eachindex(s.alive)),
     east=count(i->s.alive[i] && !west(a.current_cell[i]),eachindex(s.alive)),
     west_capacity=sum(w.capacity[k] for k in candidates if west(k)),
     east_capacity=sum(w.capacity[k] for k in candidates if !west(k)),
     families=length(families),occupied_tiles=count(>(0),assigned),
     tiles=[(key=keys_order[j],capacity=capacity[j],quota=quota[j],assigned=assigned[j]) for j in eachindex(keys_order)])
end
