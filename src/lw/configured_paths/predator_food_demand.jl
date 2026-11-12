# 暫定身体設定: 糖相当の即利用分の充足目安300。脂肪蓄積の留保と同じ値を使用。
# 脂肪・組織は空腹を消さない。身体組成なしは旧設定を維持する。
predator_food_deficit(p,physiology=nothing)=
    physiology!==nothing && hasproperty(physiology,:composition) ?
    max(0.,PREDATOR_COMPOSITION.storage_reserve_floor-physiology.composition.available) :
    max(0.,PREDATOR_ANIMAL_TRIAL.initial_food-p.food)
predator_hunger(p,physiology=nothing)=predator_food_deficit(p,physiology)/PREDATOR_COGNITION.food_pressure_scale
# 暫定固定: shared_body=true の動物単独実験で有効、falseで旧候補へ戻す。
# 現在の身体備蓄と既存の初期備蓄目安を用い、食料獲得の無益な開始を抑える。
# 他個体/獲物の隠れた状態は参照しない。消化・保存・先々の需要予測へ将来置換する。
function configured_predator_food_demand!(rows,p,mind;physiology=nothing)
    rule=PREDATOR_COGNITION;world_rule=PREDATOR_ANIMAL_TRIAL
    deficit=predator_food_deficit(p,physiology)
    hunt_gain=max(0.,get(mind.estimates,"hunt",rule.hunt_prior))*rule.food_value_scale
    useful_gain=min(deficit,hunt_gain)
    for candidate in rows
        candidate["action"] in (:hunt,:visit_food,:cross_river) || continue
        # A food waypoint includes the subsequent acquisition episode, not just arrival.
        cost=predator_cost_rate(mind,candidate["action"])*candidate["forecast"]+
            (candidate["action"] in (:visit_food,:cross_river) ? predator_cost_rate(mind,:hunt)*rule.episode_ticks : 0.)
        candidate["food_demand_forecast"]=(deficit=deficit,useful_gain=useful_gain,cost=cost,
            net=(deficit-cost)/rule.food_value_scale)
        candidate["action"]==:hunt && (candidate["expected"]=(useful_gain-cost)/rule.food_value_scale)
    end
    filter!(c->!haskey(c,"food_demand_forecast") || c["food_demand_forecast"].net>0,rows)
    if !any(c->c["action"] in (:hunt,:visit_food),rows)
        push!(rows,LW.D("method"=>"idle","action"=>:idle,"question"=>"conserve_energy",
            "priority"=>0.,"forecast"=>rule.decision_ticks,
            "expected"=>-world_rule.daily_food/world_rule.day_ticks*rule.decision_ticks/rule.food_value_scale))
    end
    rows
end
