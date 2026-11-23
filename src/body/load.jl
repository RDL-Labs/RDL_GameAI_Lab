# Transitional loader for existing scripts sharing a caller module.
if !isdefined(@__MODULE__, :RDLBody)
    include("RDLBody.jl")
end
using .RDLBody: Body, Digestion, can_ingest, taste, ingest!, digest!, digestion_snapshot
using .RDLBody: GUT_CAPACITY, DIGEST_SECONDS, MEAL_ENERGY, FOOD_LIKING
using .RDLBody: BodyDelta, step, metabolize, RS, SS
using .RDLBody: AbstractBody, HumanBody, body_energy, body_alive, body_mobility, body_demand, body_food_gap, body_spendable, body_energy_delta, body_observed_energy, body_observed_demand
