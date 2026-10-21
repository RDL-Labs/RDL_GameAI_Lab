mutable struct World
    xmin::Float64; zmin::Float64; xmax::Float64; zmax::Float64
    cellsize::Float64; nx::Int; nz::Int; phase::Float64
    material::Vector{UInt8}; walkable::BitVector
    grass::Vector{Float64}; capacity::Vector{Float64}; updated::Vector{Int}
    obstacles::Vector{RDLMigrationProbe.Circle}
    grown::Float64; eaten::Float64; initial::Float64
end
mutable struct Animals
    x::Vector{Float64}; z::Vector{Float64}; heading::Vector{Float64}
    energy::Vector{Float64}; gut::Vector{Float64}; sleepy::Vector{Float64}
    state::Vector{UInt8}; previous_cell::Vector{Int32}; current_cell::Vector{Int32}
    target::Vector{Int32}; next_sense::Vector{Int}
    distance::Vector{Float64}; consumed::Vector{Float64}; digested::Vector{Float64}
    starvation_ticks::Vector{Int}; blocked::Vector{Int}; counts::Matrix{Int}
end
