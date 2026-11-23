abstract type AbstractBody end
# Legacy four-scalar physiology retained only for old fixtures/animal adapters.
struct Body <: AbstractBody
    burst::Float64
    strain::Float64
    reserve::Float64
    damage::Float64
end
