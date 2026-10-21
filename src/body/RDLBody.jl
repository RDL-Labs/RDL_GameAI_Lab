module RDLBody

export Body, Digestion, can_ingest, taste, ingest!, digest!, digestion_snapshot
export GUT_CAPACITY, DIGEST_SECONDS, MEAL_ENERGY, FOOD_LIKING
export BodyDelta, step, metabolize, RS, SS
export ORDINARY_FOOD, MEAT_FOOD, FOOD_KIND_IDS, FOOD_KIND_LABELS

include("types.jl")
include("../data/food_ids.jl")
include("actions.jl")
include("digestion.jl")

end
