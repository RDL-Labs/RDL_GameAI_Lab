module RDLBody

export Body, Digestion, can_ingest, taste, ingest!, digest!, digestion_snapshot
export GUT_CAPACITY, DIGEST_SECONDS, MEAL_ENERGY, FOOD_LIKING
export BodyDelta, step, metabolize, RS, SS
export FRUIT_FOOD, ORDINARY_FOOD, MEAT_FOOD, FOOD_KIND_IDS, FOOD_KIND_LABELS
export RAW_ACORN, ACORN_MEAL, FOOD_EDIBLE, FOOD_STORAGE, FOOD_PROCESS_OUTPUT, FOOD_PROCESS_TICKS, food_edible

include("types.jl")
include("../data/food_ids.jl")
include("actions.jl")
include("digestion.jl")

end
