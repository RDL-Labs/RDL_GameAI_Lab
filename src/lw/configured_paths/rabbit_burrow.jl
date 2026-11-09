# 暫定固定の世界規則：離乳前は出生位置の巣穴内。掘削/入口/内部地形は省略。
# enabled=true（既定）、繁殖OFFでは無効。設定をfalseにすると従来の草上待機。
# 視覚と捕獲だけを遮断し、授乳・飢餓・匂いは維持。離乳時に自動的に地上へ出る。
# 将来は穴への出入りと観測可能な入口を持つ環境/行動に置換する。
const RABBIT_BURROW=(enabled=true,rule="dependent-young-inaccessible-at-birth-site")
# 暫定固定: 自分の出生巣を知っている近距離の幼体のみ退避。
# 距離2は世界距離の初期値。安全時の通常採食は維持。将来は避難場所MBへ置換。
# enabled=falseで従来の巣外への逃走に戻す。母親/離乳後への保護拡大なし。
const RABBIT_BURROW_REFUGE=(enabled=true,near_distance=2.)
configured_burrow_refuge_enabled()=RABBIT_BURROW_REFUGE.enabled
function configured_rabbit_refuge_goal(s,i,t)
    configured_burrow_refuge_enabled() && RABBIT_BURROW.enabled && s.life!==nothing || return nothing
    s.life.mother[i]>0 && dependent(s.life,i,t) || return nothing
    nest=s.life.nest[i]
    hypot(s.animals.x[i]-nest[1],s.animals.z[i]-nest[2])<=RABBIT_BURROW_REFUGE.near_distance ? nest : nothing
end
function configured_rabbit_refuge_response!(s,i,t)
    configured_rabbit_refuge_goal(s,i,t)===nothing && return
    s.overrides[i] in (H.ALERT,H.FLEE) || return
    s.overrides[i]=configured_rabbit_in_burrow(s,i,t) ? H.REST : H.FLEE
end
configured_rabbit_in_burrow(s,i,t)=RABBIT_BURROW.enabled && s.life!==nothing &&
    s.life.mother[i]>0 && dependent(s.life,i,t) &&
    (!configured_rabbit_self_feeding(s,i,t) || hypot(s.animals.x[i]-s.life.nest[i][1],s.animals.z[i]-s.life.nest[i][2])<=RABBIT_JUVENILE_GROWTH.burrow_radius)
