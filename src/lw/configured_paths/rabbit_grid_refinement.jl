# 暫定固定の比較用初期世界設定。既定2m、明示1mのみ分割。行動強制はしない。
# 既存の面積当たり容量・植生・初期位置を保存し、草資源の区画だけ4分割する。
# 地形の再サンプリングはしない。実移動/視線は既存連続形状で確認する。
function configured_rabbit_refine_grid!(s,cellsize)
    w=s.world
    cellsize==w.cellsize && return
    cellsize==1. && w.cellsize==2. && s.ticks==0 && w.layers===nothing || error("only fresh 2m to 1m refinement supported")
    oldnx=w.nx;oldnz=w.nz;nx=2oldnx;nz=2oldnz
    parent=[div(x,2)+1+div(z,2)*oldnx for z in 0:nz-1 for x in 0:nx-1]
    w.capacity=w.capacity[parent]./4;w.grass=w.grass[parent]./4;w.updated=w.updated[parent]
    w.material=w.material[parent];w.walkable=w.walkable[parent]
    if w.traits!==nothing
        t=w.traits;w.traits=H.WorldFeatures.GrassTraits(t.color[parent],t.height[parent],t.density[parent],t.patch[parent])
    end
    w.nx=nx;w.nz=nz;w.cellsize=cellsize
    s.demand=zeros(length(parent));s.ratio=zeros(length(parent));empty!(s.active)
    for i in eachindex(s.alive)
        s.animals.current_cell[i]=H.cell(w,s.animals.x[i],s.animals.z[i])
        s.animals.previous_cell[i]=0;s.animals.target[i]=0;s.animals.next_sense[i]=0
    end
end
