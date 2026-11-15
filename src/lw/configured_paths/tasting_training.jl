# 暫定固定: configured_tasting_training=false(既定)。1日1種類の実食研修。
# 通常のretrieve/eatを実行し、味の記憶そのものは捏造しない。実食後は翌日まで待機。
# 初期教示の代替であり、将来は自律的な試食へ置換。
const TASTING_TRAINING_KINDS=(1,4,8)
function configured_tasting_supply(supply,day)
    day>=length(TASTING_TRAINING_KINDS) && return supply
    Dict(String(actor)=>D("kind"=>TASTING_TRAINING_KINDS[day+1],"quantity"=>row["quantity"]) for (actor,row) in pairs(supply))
end
configured_tasted(map,kind)=get(get(get(map,"food_taste_experiences",D()),food_taste_key(kind,2),D()),"samples",0)>0
function configured_tasting_plan(map,foods,actor,can_eat,at_home,day)
    day>=length(TASTING_TRAINING_KINDS) && return nothing
    at_home || error("tasting training requires camp placement")
    kind=TASTING_TRAINING_KINDS[day+1]
    action=configured_tasted(map,kind) ? "rest" : kind in foods.inventory[actor] ? (can_eat ? "eat" : "rest") : "retrieve"
    D("action"=>action,"food_kind"=>kind,"food_quality"=>2,"method"=>"tasting_training",
        "configured_rule"=>"tasting_training","configured_observation"=>true)
end
function configured_tasting_ready!(maps,day,now)
    day<length(TASTING_TRAINING_KINDS) && return
    for actor in IDS
        all(k->configured_tasted(maps[actor],k),TASTING_TRAINING_KINDS) || error("tasting training incomplete: $actor")
        get!(() -> D("completed_us"=>now,"kinds"=>collect(TASTING_TRAINING_KINDS)),maps[actor],"tasting_training")
    end
end
