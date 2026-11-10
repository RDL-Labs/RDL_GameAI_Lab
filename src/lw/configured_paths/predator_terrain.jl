# 暫定の世界/身体条件。通常OFF、動物実験で明示ON（world単位）。
# 川を禁止地形ではなく低速・高消費の地形とする。種共通の地形身体モデルへ将来統合。
# 正確な地形参照は従来の衝突と同じ近道。休息禁止や渡河継続強制はしない。
const PREDATOR_TERRAIN=(water_speed=.12,water_move_multiplier=4.)
const PREDATOR_TERRAIN_WORLDS=WeakKeyDict{Any,Bool}()
configured_predator_terrain_enabled(w)=get(PREDATOR_TERRAIN_WORLDS,w,false)
configured_predator_terrain_enable!(w;enabled=true)=(PREDATOR_TERRAIN_WORLDS[w]=enabled)
configured_predator_terrain_wet(w,p,q)=any(point->H.material(w.phase,point...)==H.WATER,
    (p,q,((p[1]+q[1])/2,(p[2]+q[2])/2)))
function configured_predator_terrain_clear(w,p,q)
    configured_predator_terrain_enabled(w) || return H.clear(w,p,q)
    w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25 || return false
    !any(o->H.RDLMigrationProbe.segment_hit(p,q,o,.25),w.obstacles)
end
function configured_predator_terrain_speed(w,p,heading,speed)
    configured_predator_terrain_enabled(w) || return speed
    q=(p[1]+speed*cos(heading),p[2]+speed*sin(heading))
    configured_predator_terrain_wet(w,p,q) ? min(speed,PREDATOR_TERRAIN.water_speed) : speed
end
function configured_predator_terrain_extra_distance(w,p,q)
    configured_predator_terrain_enabled(w) && configured_predator_terrain_wet(w,p,q) || return 0.
    hypot(q[1]-p[1],q[2]-p[2])*(PREDATOR_TERRAIN.water_move_multiplier-1)
end
