# 暫定の地形身体条件。泳ぎ対応LWでON。通常移動にも水の低速・高消費を適用。
# 正確な地形参照は衝突と同じ近道。将来は種共通の身体・地形モデルへ置換。
const RABBIT_TERRAIN=(enabled=true,water_speed=.10,water_cost_multiplier=3.,probe_spacing=.5)
configured_rabbit_terrain_wet(w,p,q)=any(v->material(w.phase,v...)==WATER,(p,q,((p[1]+q[1])/2,(p[2]+q[2])/2)))
function configured_rabbit_terrain_distance(w,p,q)
    distance=hypot(q[1]-p[1],q[2]-p[2])
    RABBIT_TERRAIN.enabled || return distance
    steps=max(1,ceil(Int,distance/RABBIT_TERRAIN.probe_spacing))
    wet=count(j->material(w.phase,p[1]+(q[1]-p[1])*(j-.5)/steps,p[2]+(q[2]-p[2])*(j-.5)/steps)==WATER,1:steps)
    distance*(1+(RABBIT_TERRAIN.water_cost_multiplier-1)*wet/steps)
end
