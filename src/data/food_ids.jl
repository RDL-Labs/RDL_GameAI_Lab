# Stable food IDs; liking and nutrition belong to physiology, not identity.
const FRUIT_FOOD=1
const ORDINARY_FOOD=FRUIT_FOOD # legacy name; existing kind 1 is now explicitly fruit
const MEAT_FOOD=2
const RAW_ACORN=3
const ACORN_MEAL=4
const FISH_FOOD=5
const COOKED_FISH=7
const SALTED_FISH=8
const SPOILED_FOOD=6 # shared rotten food state; not a disappearance
const FOOD_KIND_IDS=(FRUIT_FOOD,MEAT_FOOD,RAW_ACORN,ACORN_MEAL,FISH_FOOD,SPOILED_FOOD,COOKED_FISH,SALTED_FISH)
const FOOD_KIND_LABELS=("fruit","meat","raw_acorn","acorn_meal","raw_fish","spoiled_food","cooked_fish","salt_grilled_fish")
const FOOD_APPEARANCE=("red_round_fruit","red_flesh","brown_capped_ovoid","brown_meal","silver_fish","grey_flesh","roasted_fish","salt_grilled_fish")
# Game resource properties. Fish expires at the next world day boundary.
const FOOD_EDIBLE=(true,true,true,true,false,false,true,true) # raw acorn is unpleasant in this simplified game model
const FOOD_STORAGE=("ordinary","ordinary","long","long","same_day","spoiled","same_day","same_day")
const FOOD_PROCESS_OUTPUT=(0,0,ACORN_MEAL,0,COOKED_FISH,0,0,0)
const FOOD_PROCESS_TICKS=(0,0,120,0,120,0,0,0)
food_edible(kind)=kind in FOOD_KIND_IDS && FOOD_EDIBLE[kind]
