# 暫定固定・局所専用。通常OFF（実験からincludeのみ）。
# 共通MBの関係重みを使用するが、費用・再試行減点は未学習の設定。
# 将来は共通試行の予測・費用・結果評価へ置換。相手の正確な位置/向きは候補に使わない。
const CONFIRM_PROBE=(call_cost=.1,orbit_cost=.25,retry_penalty=1.,orbit_degrees=45.,max_orbit_steps=8)
function configured_confirm_candidates(identity,names,relations;calls=0,orbit_steps=0)
 rows=Any[]
 identity.status in (:ambiguous,:insufficient_observation) || return rows
 for peer in identity.candidates, name in get(names.relations,peer,String[])
  bias=LW.social_relation_bias(relations,peer,"give")["weight"]
  push!(rows,(action=:call_name,peer=peer,name=name,priority=bias-CONFIRM_PROBE.call_cost-calls*CONFIRM_PROBE.retry_penalty))
 end
 orbit_steps<CONFIRM_PROBE.max_orbit_steps && push!(rows,(action=:orbit,peer=nothing,name=nothing,priority=-CONFIRM_PROBE.orbit_cost))
 sort!(rows;by=x->(-x.priority,string(x.action),something(x.peer,""),something(x.name,"")))
 rows
end
# 世界側の検査用移動。観測から作った中心の周りへ45度。衝突時は移動しない。
function configured_confirm_orbit!(w,actor,estimated_center)
 p=w.positions[actor];dx=p[1]-estimated_center[1];dz=p[2]-estimated_center[2]
 angle=CONFIRM_PROBE.orbit_degrees
 q=(estimated_center[1]+cosd(angle)*dx-sind(angle)*dz,estimated_center[2]+sind(angle)*dx+cosd(angle)*dz)
 any(o->LW.segment_hit(p,q,o,CALL_INSPECTION.body_radius),w.obstacles) && return false
 w.positions[actor]=q
 true
end
