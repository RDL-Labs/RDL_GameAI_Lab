# 暫定固定: 満腹待機の再判断抑制。既定ON、plan! の idle_gate=false で旧方式。
# 身体と既存の可視ライバルだけを確認し、代謝・他個体からの観測は停止しない。
# 将来は共通の注意/割込み機構へ置換。停止中の試行時間と消費は復帰時にまとめる。
const PREDATOR_IDLE_GATE=(enabled=true,)
function configured_predator_idle_hold!(mind,p,rival,t,physiology;enabled=PREDATOR_IDLE_GATE.enabled)
    holding=enabled && physiology!==nothing && p.alive && mind.trial!==nothing &&
        mind.selected["action"]==:idle && rival.actor===nothing &&
        p.food>=PREDATOR_ANIMAL_TRIAL.initial_food &&
        predator_recovery_need(physiology.body)<=PREDATOR_BODY.need_band
    if holding
        get!(mind.trial,"idle_gate_since",t-1)
        return true
    end
    false
end
function configured_predator_idle_elapsed!(mind,t)
    mind.trial===nothing && return 1.
    Float64(t-pop!(mind.trial,"idle_gate_since",t-1))
end
