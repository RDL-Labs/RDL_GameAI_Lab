# Stable food IDs; liking and nutrition belong to physiology, not identity.
const FRUIT_FOOD=1
const ORDINARY_FOOD=FRUIT_FOOD # legacy name; existing kind 1 is now explicitly fruit
const MEAT_FOOD=2
const RAW_ACORN=3
const ACORN_MEAL=4
const FOOD_KIND_IDS=(FRUIT_FOOD,MEAT_FOOD,RAW_ACORN,ACORN_MEAL)
const FOOD_KIND_LABELS=("fruit","meat","raw_acorn","acorn_meal")
# Game resource properties. Storage class is metadata until spoilage is modeled.
const FOOD_EDIBLE=(true,true,false,true)
const FOOD_STORAGE=("ordinary","ordinary","long","long")
const FOOD_PROCESS_OUTPUT=(0,0,ACORN_MEAL,0)
const FOOD_PROCESS_TICKS=(0,0,120,0)
food_edible(kind)=kind in FOOD_KIND_IDS && FOOD_EDIBLE[kind]
