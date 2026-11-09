# 暫定固定の層選択。二層世界のみON。真の在庫ではなく観測した層の量を評価する。
# 短草優先、reserve55以下かつ短草密度2%未満なら長草を選ぶ。
# 長草の一口量は半分。係数は簡略モデルの仮値、将来は味/採食成果MBへ置換。
const RABBIT_GRASS_LAYERS=(fallback_reserve=55.,short_density_limit=.02,long_intake_factor=.5)
function configured_rabbit_long_grass(vegetation,energy)
    vegetation!==nothing && hasproperty(vegetation,:short_food) &&
        energy<=RABBIT_GRASS_LAYERS.fallback_reserve &&
        vegetation.short_density<RABBIT_GRASS_LAYERS.short_density_limit && vegetation.long_food>0
end
function configured_rabbit_layer_observation(vegetation,energy)
    (vegetation===nothing || !hasproperty(vegetation,:short_food)) && return vegetation
    use_long=configured_rabbit_long_grass(vegetation,energy)
    merge(vegetation,(food=use_long ? vegetation.long_food : vegetation.short_food,
        density=use_long ? vegetation.long_density : vegetation.short_density,))
end
