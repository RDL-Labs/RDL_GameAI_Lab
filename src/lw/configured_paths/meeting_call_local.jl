# 暫定固定・局所のみ、通常LW未include/既定OFF。
# 待ち合わせpeerと既知の名前を使う確認行動。将来は共通MB候補へ置換。
# 通常identity_callの可聴範囲・再発話間隔・失効を再利用する。
# 応答は注意方向の変更であり、取引同意/人物同定の確定ではない。
function configured_meeting_call_local(state,relation,sight,yaw,now,day_us;busy=false)
    busy && return nothing # 局所の作業優先設定。声は受信済みのまま期限まで保持。
    if configured_identity_call_notice!(relation,now)!==nothing
        return configured_identity_call_plan!(relation,yaw,now,day_us)
    end
    meeting=configured_camp_trade_state!(state)["meeting"]
    meeting===nothing && return nothing
    identity=get(relation,"identity_observation",nothing)
    identity===nothing && return nothing
    peer=meeting["peer"]
    seen=findfirst(p->p["ref"]==peer,sight["peers"])
    seen===nothing && return nothing
    name=get(identity["names"],peer,nothing);name===nothing && return nothing
    calls=configured_identity_calls_state!(relation)
    now>=calls["next_us"] || return nothing
    D("action"=>"scan","method"=>"meeting_name_call","configured_rule"=>"meeting_call_local",
        "scan_angle"=>sight["peers"][seen]["angle"],"identity_call_name"=>name,"configured_observation"=>true)
end
