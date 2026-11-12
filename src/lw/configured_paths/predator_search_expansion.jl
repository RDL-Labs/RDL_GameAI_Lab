include("../../common/relational_expansion.jl")
# 暫定探索表現: 自己位置と世界境界だけで仮目標を置く。獲物分布は参照しない。
# 既定ON。mind.estimates["search_expansion_enabled"]=0で旧探索へ戻す。
# Hは既存の未解決採食評価から読むだけで加算しない。到着は食料成果にしない。
# 半径4..64、H2、曲率3、到着2、時間余裕2は未較正。将来は観測MBの区画候補に置換。
# 暫定: 実際の嗅覚確認3回連続で手掛かりなしなら半径下限32。未観測は対象外。
const PREDATOR_NO_CUE_SEARCH=(enabled=true,missing_sniffs=3,minimum_radius=32.)
const PREDATOR_SEARCH_EXPANSION=(enabled=true,minimum_radius=4.,maximum_radius=64.,
    full_H=2.,curvature=3.,arrival_radius=2.,timeout_factor=2.,boundary_margin=2.)
function configured_predator_search_expansion!(mind,p,w,t;physiology=nothing,search_attention=nothing)
    r=PREDATOR_SEARCH_EXPANSION
    get(mind.estimates,"search_expansion_enabled",r.enabled ? 1. : 0.)>0 || return
    p.alive && p.mode==:hunt && p.visual.body.state==P.SEARCH && search_attention===nothing || return
    b=p.visual.body
    pressure=predator_foraging_selection_H(mind,p,physiology)
    fraction=relational_expansion_fraction(pressure;full_H=r.full_H,curvature=r.curvature)
    radius=r.minimum_radius+(r.maximum_radius-r.minimum_radius)*fraction
    no_cue=get(mind.estimates,"no_cue_search_enabled",PREDATOR_NO_CUE_SEARCH.enabled ? 1. : 0.)>0 &&
        get(mind.estimates,"search:missing_sniffs",0.)>=PREDATOR_NO_CUE_SEARCH.missing_sniffs &&
        0<=t-get(mind.estimates,"search:sniff_tick",-Inf)<=PREY_SCENT.sniff_interval
    no_cue && (radius=max(radius,PREDATOR_NO_CUE_SEARCH.minimum_radius))
    e=mind.estimates
    target_x=get(e,"search:target_x",b.x);target_z=get(e,"search:target_z",b.z)
    expired=t>=get(e,"search:expires",-1.)
    arrived=hypot(target_x-b.x,target_z-b.z)<=r.arrival_radius
    expanded=no_cue && get(e,"search:radius",0.)<PREDATOR_NO_CUE_SEARCH.minimum_radius
    if expired || arrived || expanded
        angle=2pi*rand(mind.loop.rng)
        # Geometry clamp is a declared shortcut, not knowledge of prey or reachability.
        target_x=clamp(b.x+radius*cos(angle),w.xmin+r.boundary_margin,w.xmax-r.boundary_margin)
        target_z=clamp(b.z+radius*sin(angle),w.zmin+r.boundary_margin,w.zmax-r.boundary_margin)
        e["search:target_x"]=target_x;e["search:target_z"]=target_z
        e["search:expires"]=t+r.timeout_factor*radius/PREDATOR_COGNITION.move_speed
        e["search:choices"]=get(e,"search:choices",0.)+1
        e["search:radius"]=radius;e["search:pressure"]=pressure
        e["search:max_radius"]=max(get(e,"search:max_radius",0.),radius)
    end
    b.heading=atan(target_z-b.z,target_x-b.x)
end

# Call only after the scheduled sniff. No mark/world lookup here.
function configured_predator_search_cue!(mind,p,observation,t)
    t%PREY_SCENT.sniff_interval==0 || return
    p.alive && p.mode==:hunt && !(p.visual.body.state in (P.ATTACK,P.CHASE,P.RECOVER)) || return
    e=mind.estimates
    get(e,"search:sniff_tick",-1.)==t && return
    e["search:sniff_tick"]=t
    if observation===nothing
        e["search:missing_sniffs"]=get(e,"search:missing_sniffs",0.)+1
    else
        was_missing=get(e,"search:missing_sniffs",0.)>=PREDATOR_NO_CUE_SEARCH.missing_sniffs
        e["search:missing_sniffs"]=0.
        # Preserve previous H-only behavior when disabled for comparison.
        if was_missing && get(e,"no_cue_search_enabled",PREDATOR_NO_CUE_SEARCH.enabled ? 1. : 0.)>0
            e["search:expires"]=-1.
        end
    end
end