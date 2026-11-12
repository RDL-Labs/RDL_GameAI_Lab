# 暫定認知設定: 採食方法全体の不成果を選択時のHへ接続する。既定ON。
# 身体の自己消費・摂取だけを使用し、獲物の真の分布は読まない。
# 強制離脱や巡回禁止はしない。将来は維持需要の学習予測に置換する。
const PREDATOR_FORAGING_PRESSURE=(enabled=true,hunger_gain=1.)
function predator_foraging_result!(mind,action,spent,gained)
    PREDATOR_FORAGING_PRESSURE.enabled || return
    action in (:hunt,:visit_food,:cross_river) || return
    key="foraging:uncovered_cost"
    mind.estimates[key]=max(0.,get(mind.estimates,key,0.)+max(0.,spent)-max(0.,gained))
end
function configured_predator_foraging_pressure!(rows,mind,p;physiology=nothing)
    PREDATOR_FORAGING_PRESSURE.enabled || return rows
    hunger=predator_hunger(p,physiology)
    amplification=1+PREDATOR_FORAGING_PRESSURE.hunger_gain*hunger
    unresolved=get(mind.estimates,"foraging:uncovered_cost",0.)/PREDATOR_COGNITION.food_value_scale
    # Same failure evidence is not added to parent H twice; use the stronger estimate.
    selection_H=max(mind.loop.H,unresolved)*amplification
    current_site=predator_near_food_site(mind,p)
    for candidate in rows
        site=get(candidate,"site",candidate["action"]==:hunt ? current_site : nothing)
        site_pressure=site===nothing ? 0. : predator_food_site_repulsion(mind,site)
        # Existing visit penalty is already present. Hunt must also evaluate its current site.
        prior=get(candidate,"food_site_repulsion",0.)
        candidate["priority"]-=site_pressure*amplification-prior
        candidate["decision_H"]=selection_H
        candidate["foraging_pressure"]=(unresolved=unresolved,hunger=hunger,selection_H=selection_H,site_pressure=site_pressure*amplification)
    end
    rows
end
