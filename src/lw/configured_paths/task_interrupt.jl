include("parameters.jl")

# 暫定固定: task_interrupt_shield=true (既定)。作業中の弱い動体割込みを抑える。
# 自分の食料不安とゲーム作業進捗を直接参照するショートカット。
# 身体限界・定期再観測は遮断しない。将来はMBの作業期待と注意配分へ置換。
# 診断は task_focus.last_interrupt / suppressed_motion に保存する。
function configured_task_interrupt(motion,need,progress;enabled=true)
    p=TASK_INTERRUPT_RULES
    n=max(0.,Float64(need));q=clamp(Float64(progress),0.,1.)
    focus=p.need_weight*n/(p.need_scale+n)+p.progress_weight*q
    radius=max(p.close_range,TASK_ATTENTION.motion_range/(1+focus))
    distance=get(motion,"distance",nothing)
    # Unknown/invalid sensor evidence cannot justify suppression. Equality wakes.
    wake=!enabled || distance===nothing || !isfinite(distance) || distance<=radius
    (wake=wake,radius=radius,need=n,progress=q)
end

# Owner-side elapsed work only: no future catch, hidden stock or other inventory.
function configured_task_progress(foods,a,action)
    foods===nothing && return 0.
    if action=="fish"
        state=get(foods.game.fishing,a,nothing)
        state===nothing && return 0.
        active=get(state,"active",nothing)
        return active===nothing ? 0. : clamp(active["ticks"]/GAME_FISHING_TICKS,0.,1.)
    elseif action=="process_food"
        recipe,done=foods.progress[a]
        kind=recipe==RDLBody.SALTED_FISH ? RDLBody.FISH_FOOD : Int(recipe)
        ticks=kind in RDLBody.FOOD_KIND_IDS ? RDLBody.FOOD_PROCESS_TICKS[kind] : 0
        return ticks>0 ? clamp(done/ticks,0.,1.) : 0.
    end
    0.
end
