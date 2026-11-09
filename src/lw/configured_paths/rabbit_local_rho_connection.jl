# 暫定固定接続: 対象個体/時刻の限定なし。通常候補がある間は追加観測しない。
# SEARCHだけで細候補を使い、幼体の行動範囲も適用。逃走/泳ぎには介入しない。
# 採食が再開したら候補なしの圧は解消。その他の行動では細目標を中断する。
configured_rabbit_rho_heading!(policy,w,a,i,t,base;allowed=q->true)=base
function configured_rabbit_rho_heading!(policy::Union{RabbitApproachPolicy,RabbitSwimmingPolicy},w,a,i,t,base;allowed=q->true)
    RABBIT_LOCAL_RHO.enabled || return base
    policy isa RabbitSwimmingPolicy && haskey(policy.trips,i) && return base
    m=approach_memory(rabbit_approach_base(policy),i);r=m.local_rho
    if a.target[i]!=0 && r.H==0 && r.waypoint===nothing;return base;end
    configured_rabbit_local_rho!(r,w,a,i,t,base;geometry=@__MODULE__,allowed)
end
configured_rabbit_rho_progress!(policy,a,i,t)=nothing
function configured_rabbit_rho_progress!(policy::Union{RabbitApproachPolicy,RabbitSwimmingPolicy},a,i,t)
    base=rabbit_approach_base(policy)
    haskey(base.actors,i) || return
    r=base.actors[i].local_rho
    a.state[i]==SEARCH && return
    r.waypoint=nothing
    if a.state[i]==GRAZE && r.H>0
        rho_record!(r,(event="feeding_restored",tick=t,H=r.H))
        r.H=0.;r.missing_ticks=0;empty!(r.visits)
    end
end
function rabbit_rho_snapshot(policy)
    policy isa Union{RabbitApproachPolicy,RabbitSwimmingPolicy} || return nothing
    memories=values(rabbit_approach_base(policy).actors)
    totals=Dict{String,Int}()
    for m in memories,(key,value) in m.local_rho.counts;totals[key]=get(totals,key,0)+value;end
    (queries=sum((m.local_rho.queries for m in memories);init=0),
     actors=count(m->m.local_rho.queries>0,memories),events=totals)
end

function rabbit_food_pressure_snapshot(policy)
    policy isa Union{RabbitApproachPolicy,RabbitSwimmingPolicy} || return nothing
    memories=values(rabbit_approach_base(policy).actors)
    (actors=length(memories),calls=sum((m.food_gate.calls for m in memories);init=0),
     active_calls=sum((m.food_gate.active_calls for m in memories);init=0),
     active=count(m->m.food_gate.active,memories),
     peakH=maximum((m.food_pressure.peak for m in memories);init=0.))
end
