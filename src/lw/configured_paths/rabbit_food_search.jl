# 暫定認知見積もり: 120 SEARCH tickで予備量1.44の回復を期待する。
# 歩数/区画到着は成功にしない。胃内容を含む回復でのみ解消。
# enabled=falseで従来方式。記録内の状態を保存し旧checkpointの構造互換を維持。
# 将来は食料確保MBの経験見積もりへ置換。身体を補正せず強制移動もしない。
const RABBIT_FOOD_SEARCH=(enabled=true,forecast_ticks=120,recovery_gain=1.44,
    full_reserve=85.,range_H=4.,maximum_radius=3)
function configured_food_search_state(parent)
    index=findlast(r->r.event=="food_search_state",parent.records)
    index===nothing ? nothing : parent.records[index]
end
function configured_food_search_store!(parent,state)
    if !isempty(parent.records) && parent.records[end].event=="food_search_state"
        parent.records[end]=state;return
    end
    filter!(r->r.event!="food_search_state",parent.records)
    push!(parent.records,state)
    while length(parent.records)>RABBIT_FOOD_PRESSURE_CONNECTION.history_limit;popfirst!(parent.records);end
end
function configured_food_search_update!(parent,a,i,t;search_tick=false,intake=false)
    RABBIT_FOOD_SEARCH.enabled || return
    rule=RABBIT_FOOD_SEARCH;reserve=a.energy[i]+RABBIT_FOOD_PRESSURE.gut_conversion*a.gut[i]
    state=configured_food_search_state(parent)
    if state===nothing || !state.active
        search_tick || return
        state=(event="food_search_state",active=true,tick=t,goal=min(rule.full_reserve,reserve+rule.recovery_gain),search_ticks=0)
    end
    ticks=state.search_ticks+(search_tick ? 1 : 0)
    achieved=intake && reserve>=state.goal
    state=merge(state,(active=!achieved,search_ticks=ticks,))
    configured_food_search_store!(parent,state)
    achieved && (parent.H=0.;parent.expected=nothing)
end
function configured_food_search_pressure(parent,reserve)
    state=configured_food_search_state(parent)
    state===nothing || !state.active ? 0. :
        max(0.,state.search_ticks/RABBIT_FOOD_SEARCH.forecast_ticks-1)*
        max(0.,state.goal-reserve)/RABBIT_FOOD_PRESSURE.residual_scale
end
configured_food_search_radius(pressure)=RABBIT_FOOD_SEARCH.enabled ?
    clamp(1+floor(Int,max(0.,pressure)/RABBIT_FOOD_SEARCH.range_H),1,RABBIT_FOOD_SEARCH.maximum_radius) : 1

