# 暫定身体近似。明示RabbitCompositionStateでのみON、通常LW/既存保存は変更しない。
# 兎の既存energy(0..100)を組成へ分配。体格成長は従来heightのまま。
# 正規化した体調組成でありグラムではない。将来は栄養別同化/組織成長へ置換。
const RABBIT_COMPOSITION=(protein_min=15.,protein_target=30.,collapse_protein=22.5,
    initial_fat=20.,reserve_floor=35.,fat_capacity=40.,storage_per_day=1.,repair_per_day=2.,
    reference_edible=50.) # reference protein30 + fat20; predator-specific conversion retained.
mutable struct RabbitCompositionState
    bodies::Vector{LW.RDLBody.Composition}
    dependent::BitVector
    max_balance_error::Float64
end
function configured_rabbit_composition_body(energy)
    r=RABBIT_COMPOSITION
    tissue=min(energy,r.protein_target-r.protein_min)
    fat=min(max(0.,energy-tissue),r.initial_fat)
    LW.RDLBody.Composition(available=max(0.,energy-tissue-fat),fat=fat,
        protein=r.protein_min+tissue,protein_min=r.protein_min,
        protein_target=r.protein_target,collapse_protein=r.collapse_protein)
end
rabbit_composition_dependent(s,i)=s.life!==nothing && G.dependent(s.life,i,s.ticks)
RabbitCompositionState(s)=RabbitCompositionState(configured_rabbit_composition_body.(s.animals.energy),BitVector([rabbit_composition_dependent(s,i) for i in eachindex(s.alive)]),0.)
function configured_rabbit_composition_sync!(state,s)
    r=RABBIT_COMPOSITION
    while length(state.bodies)<length(s.alive)
        i=length(state.bodies)+1
        push!(state.bodies,configured_rabbit_composition_body(s.animals.energy[i]))
        push!(state.dependent,rabbit_composition_dependent(s,i))
    end
    for i in eachindex(s.alive)
        s.alive[i] || continue # Keep the carcass composition for the capturing consumer.
        dependent_now=rabbit_composition_dependent(s,i)
        if state.dependent[i] && !dependent_now
            # 暫定発達境界: 離乳時に既存エネルギーから成人用配分を初期化。
            # 蓄積を追加しない。将来は連続的な組織成長へ置換。
            state.bodies[i]=configured_rabbit_composition_body(s.animals.energy[i])
        end
        state.dependent[i]=dependent_now
        body=state.bodies[i];observed_energy=s.animals.energy[i]
        delta=observed_energy-LW.RDLBody.composition_energy(body)
        external_feed=body.fed_since_collapse
        delta>0 ? LW.RDLBody.composition_feed!(body,delta) : LW.RDLBody.composition_consume!(body,-delta)
        # Adult gut digestion is not outside rescue. Nursing remains external food for young.
        !dependent_now && body.collapsed && delta>0 && (body.fed_since_collapse=external_feed)
        LW.RDLBody.composition_repair!(body,r.repair_per_day/G.RABBIT_LIFE.day_ticks)
        LW.RDLBody.composition_store_fat!(body;reserve_floor=r.reserve_floor,fat_capacity=r.fat_capacity,
            rate=r.storage_per_day/G.RABBIT_LIFE.day_ticks)
        state.max_balance_error=max(state.max_balance_error,abs(observed_energy-LW.RDLBody.composition_energy(body)))
    end
    nothing
end
rabbit_composition_mobility(state,i)=state.dependent[i] ? 1. : LW.RDLBody.composition_mobility(state.bodies[i])
function configured_rabbit_meal(state,s,i,adult_food,size_fraction)
    state===nothing && return adult_food*size_fraction
    body=state.bodies[i]
    # available/gut contents are excluded; same body composition serves both predators.
    adult_food*size_fraction*(body.protein+body.fat)/RABBIT_COMPOSITION.reference_edible
end
function rabbit_composition_report(state,s)
    state===nothing && return nothing
    (rule=RABBIT_COMPOSITION,max_balance_error=state.max_balance_error,
     living=[merge((id=i,dependent=state.dependent[i],effective_mobility=rabbit_composition_mobility(state,i)),LW.RDLBody.composition_snapshot(state.bodies[i])) for i in eachindex(s.alive) if s.alive[i]])
end


# 暫定給餌API: 人の判断/接近/giveは未接続。容量100内だけ受取、復活なし。
function configured_rabbit_feed!(state,s,i,amount)
    isfinite(amount) && amount>=0 || throw(ArgumentError("rabbit feeding"))
    s.alive[i] || return 0.
    accepted=LW.RDLBody.composition_feed!(state.bodies[i],min(amount,max(0.,100-s.animals.energy[i])))
    s.animals.energy[i]+=accepted
    accepted
end

