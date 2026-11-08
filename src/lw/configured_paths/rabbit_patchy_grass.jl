# 暫定固定の世界初期条件。grass_initial_profile=patchy指定のみON、既定full。
# 容量/再生率/個体状態を変えず、20距離単位の区画ごとに初期在庫を分散する。
# 過去の採食を捏造しない。将来は準備期間による資源分布へ置換。
const RABBIT_PATCHY_GRASS=(seed=20261110,patch_width=20.,fraction_min=.2,fraction_max=1.)
function configured_rabbit_patchy_grass!(s)
    w=s.world;r=RABBIT_PATCHY_GRASS
    s.ticks==0 && w.grown==0 && w.eaten==0 || error("patchy grass requires unused initial world")
    rng=Random.Xoshiro(r.seed)
    patch_nx=ceil(Int,(w.xmax-w.xmin)/r.patch_width)
    patch_nz=ceil(Int,(w.zmax-w.zmin)/r.patch_width)
    fractions=r.fraction_min .+ (r.fraction_max-r.fraction_min).*rand(rng,patch_nx,patch_nz)
    for k in eachindex(w.grass)
        x,z=H.center(w,k)
        ix=clamp(floor(Int,(x-w.xmin)/r.patch_width)+1,1,patch_nx)
        iz=clamp(floor(Int,(z-w.zmin)/r.patch_width)+1,1,patch_nz)
        w.grass[k]=w.capacity[k]*fractions[ix,iz]
    end
    w.initial=sum(w.grass)
    (initial_grass=w.initial,capacity=sum(w.capacity),fraction=w.initial/sum(w.capacity),
     patch_fraction_min=minimum(fractions),patch_fraction_max=maximum(fractions))
end
