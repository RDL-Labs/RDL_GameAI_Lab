# 暫定固定: 捕食者の休息先の増殖による候補数の偏りを抑える。
# PREDATOR_COGNITION.single_rest_place=true が既定。falseで従来の複数地点へ戻せる。
# 最初の休息先を保持し、旧MBは休息経験数・最終経験時刻・キー順で1地点に絞る。
# 自己位置記憶の既存ショートカットを使用。移動/休息を強制しない。
# 将来は休息目的と場所選択の階層化、経験に基づく住処の変更へ置換する。
function configured_predator_rest_place!(mind)
    PREDATOR_COGNITION.single_rest_place || return nothing
    rest_keys=filter(key->mind.places[key].kind=="rest",collect(keys(mind.places)))
    isempty(rest_keys) && return nothing
    sort!(rest_keys;by=key->(-mind.places[key].successes,-mind.places[key].seen,key))
    for key in rest_keys[2:end]
        delete!(mind.places,key)
    end
    first(rest_keys)
end
