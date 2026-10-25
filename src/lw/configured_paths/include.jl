# Explicit include boundary for removable test-only configured paths.
# Dependencies (D, hunger_select) are supplied by the LW host before this include.
include(joinpath(@__DIR__, "body_maintenance.jl"))
include(joinpath(@__DIR__, "home_observation.jl"))
