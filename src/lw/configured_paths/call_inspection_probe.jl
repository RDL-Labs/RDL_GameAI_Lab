# 暫定固定・局所実験専用。通常LWにはincludeしない。
# 曖昧時coarse→medium→fine、なお曖昧なら観測方角へ接近。
# 将来は共通H/ρ/移動候補の選択へ置換。本人へ真の対象位置/IDを渡さない。
const CALL_INSPECTION=(rhos=(:coarse,:medium,:fine),step=.5,max_moves=12,near_lower=1.25,body_radius=.2)
function configured_call_inspection_choice(status,rho_index,range_lower,moves)
 status==:recognized && return :done
 status==:ambiguous || return :stop
 rho_index<length(CALL_INSPECTION.rhos) && return :raise_rho
 range_lower<=CALL_INSPECTION.near_lower && return :unresolved_near
 moves>=CALL_INSPECTION.max_moves && return :budget
 :approach
end
# 世界側の局所移動実行器。身体消費・通常経路計画を省略した検査用ショートカット。
function configured_call_inspection_move!(w,listener,bearing)
 p=w.positions[listener];q=(p[1]+CALL_INSPECTION.step*sind(bearing),p[2]+CALL_INSPECTION.step*cosd(bearing))
 any(o->LW.segment_hit(p,q,o,CALL_INSPECTION.body_radius),w.obstacles) && return false
 w.positions[listener]=q
 true
end
