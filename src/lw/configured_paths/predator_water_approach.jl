# 暫定固定: local_hunt利用時のみ既定ON。観測済み獲物/最後の観測地点への
# 直線上の水面を世界地形から参照する通行見積もり。不可なのは今の直接接近で、
# 獲物自体や親の捕食目的ではない。毎回再評価し永久ブラックリストは作らない。
# 将来は地形観測MBの不確実な到達予測/橋・迂回経路に置換する。
const PREDATOR_WATER_APPROACH=(enabled=true,sample_step=.5)
function configured_predator_water_crossing(w,origin,target;enabled=PREDATOR_WATER_APPROACH.enabled)
    P.configured_predator_terrain_enabled(w) && return false
    enabled || return false
    distance=hypot(target[1]-origin[1],target[2]-origin[2])
    steps=max(1,ceil(Int,distance/PREDATOR_WATER_APPROACH.sample_step))
    any(k->H.material(w.phase,origin[1]+(target[1]-origin[1])*k/steps,
        origin[2]+(target[2]-origin[2])*k/steps)==H.WATER,0:steps)
end
function configured_predator_water_targets!(state,s,observations,t;enabled=PREDATOR_WATER_APPROACH.enabled)
    enabled || return observations,false
    b=s.predator.body;origin=(b.x,b.z)
    reachable=filter(o->!configured_predator_water_crossing(s.world,origin,(o.x,o.z)),observations)
    rejected=length(observations)-length(reachable)
    rejected>0 && (state.counts["water_direct_rejected"]=get(state.counts,"water_direct_rejected",0)+rejected)
    current=findfirst(o->o.id==b.target,observations)
    target_position=current===nothing ? (b.seen_x,b.seen_z) : (observations[current].x,observations[current].z)
    released=b.target!=0 && configured_predator_water_crossing(s.world,origin,target_position)
    if released
        configured_local_wait_close!(state,"interrupted","direct_route_water")
        b.target=0;b.expires=t;b.pursuit=0;b.state=P.SEARCH
        state.counts["water_target_released"]=get(state.counts,"water_target_released",0)+1
    end
    reachable,rejected>0 || released
end
