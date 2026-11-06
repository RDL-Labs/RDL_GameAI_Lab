# 暫定固定：初回提示＋最大3回の条件調整。scene.configured_negotiation（既定false）。
# 目的：条件不一致を直ちに交渉全体の拒否にせず、折り合いを探す。
# 受諾不可でも実行可能な調整案があれば、打ち切りより調整を優先する。
# 将来：改善の見込み・コスト・Hから、継続／打ち切りを選ぶMBへ置換する。
# 成立は強制しない。調整案なし・最大回数後は打ち切り可能。旧方式は上限8。
include("parameters.jl")
configured_negotiation_limit(enabled)=enabled ? CONFIGURED_LIMITS.negotiation_rounds : CONFIGURED_LIMITS.legacy_negotiation_rounds
configured_negotiation_adjusting(enabled,candidates)=enabled && any(c->c["action"]=="item_counter",candidates)

# Protocol accounting is separate from per-term learning and old action counters.
function negotiation_record!(s,event)
    get(s,"configured_negotiation",false) || return
    haskey(event,"created_us") || return # unsuccessful operation, not a closed negotiation
    status=event["status"];reason=get(event,"reason",nothing)
    phase=status=="offered" ? (haskey(event,"counter_of") ? "adjusted" : "started") :
        status=="declined" && reason=="countered" ? "mismatch" :
        status=="exchanged" ? "agreed" : status=="declined" ? "ended" :
        status in ("expired","unavailable") ? "interrupted" : nothing
    phase===nothing && return
    event["negotiation_id"]=get(event,"root_id",event["id"])
    event["negotiation_status"]=phase
    stats=s["negotiations"];stats["counts"][phase]+=1
    item_push!(stats["records"],D("id"=>event["negotiation_id"],"status"=>phase,
        "round"=>get(event,"round",0),"us"=>event["us"],"reason"=>reason),128)
end
