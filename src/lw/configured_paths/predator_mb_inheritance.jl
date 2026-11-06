# 暫定固定・実験用の世代コピー。通常LW/動物実験では呼ばない（既定OFF）。
# 生存時間による親選択は実験者の操作であり個体の学習/繁殖能力ではない。
# 同一地形専用。将来は場所の対応付けや社会的学習などを別途設計する。
function configured_inherit_loop!(recipient,donor)
    recipient.methods=deepcopy(donor.methods)
    recipient.threshold=donor.threshold
    recipient.sequence=donor.sequence # Preserve method recency order, not active trials.
    # New actor identity, RNG, parent H, trial, receipt and transient history stay fresh.
    recipient
end
function configured_predator_mb_inherit(donor_mind,donor_local,actor,generation,donor_tick)
    mind=PredatorMind(actor);local_state=LocalHunt(actor;probabilistic_capture=true)
    mind.loop=LW.BasicLoop("predator:$actor:maintain";probabilistic=true,seed=20261106+1000*generation+actor)
    local_state.loop=LW.BasicLoop("predator:$actor:capture";probabilistic=true,seed=20261107+1000*generation+actor)
    configured_inherit_loop!(mind.loop,donor_mind.loop)
    configured_inherit_loop!(local_state.loop,donor_local.loop)
    mind.estimates=deepcopy(donor_mind.estimates)
    mind.places=Dict{String,Any}(key=>merge(place,(seen=place.seen-donor_tick,)) for (key,place) in donor_mind.places)
    configured_predator_rest_place!(mind)
    source=get(donor_mind.acquisition,"acquisition",nothing)
    if source!==nothing
        target=LW.acquisition_state()
        target["sites"]=deepcopy(source["sites"])
        target["methods"]=deepcopy(source["methods"])
        # Completed summaries remain evidence, but never resume prior trials or clocks.
        mind.acquisition["acquisition"]=target
    end
    local_state.capture_experience=deepcopy(donor_local.capture_experience)
    mind,local_state
end
configured_predator_lifetime(p)=sum(n for (mode,n) in p.ticks if mode!=:dead;init=0)
# Equal survival at the day limit is censored; use actor order, not an invented fitness score.
configured_survivor_index(predators)=argmax(configured_predator_lifetime.(predators))
