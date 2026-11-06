# Compatibility entry point; scheduled policy is explicitly configured.
include(joinpath(@__DIR__, "../configured_paths/return_purpose.jl"))
returning!(args...)=configured_returning!(args...)
