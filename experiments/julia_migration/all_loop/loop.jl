# Compatibility entry; canonical implementation is in src or integrations.
include(joinpath(@__DIR__, "../../../src/lw/simulation/legacy_loop.jl"))
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

