# Stable food IDs; liking and nutrition belong to physiology, not identity.
const ORDINARY_FOOD=1
const MEAT_FOOD=2
const RAW_ACORN=3
const ACORN_MEAL=4
const FOOD_KIND_IDS=(ORDINARY_FOOD,MEAT_FOOD,RAW_ACORN,ACORN_MEAL)
const FOOD_KIND_LABELS=("ordinary","meat","raw_acorn","acorn_meal")
# Game resource properties. Storage class is metadata until spoilage is modeled.
const FOOD_EDIBLE=(true,true,false,true)
const FOOD_STORAGE=("ordinary","ordinary","long","long")
const FOOD_PROCESS_OUTPUT=(0,0,ACORN_MEAL,0)
const FOOD_PROCESS_TICKS=(0,0,120,0)
food_edible(kind)=kind in FOOD_KIND_IDS && FOOD_EDIBLE[kind]
