# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function ground_resistance(p, patches)
    #= none:2 =#
    #= none:3 =#
    value = 1.5
    #= none:4 =#
    for patch = patches
        #= none:5 =#
        isfinite(patch.resistance) && patch.resistance >= 1.5 || error(NID(0x0000000000000379))
        #= none:6 =#
        if hypot(p[1] - patch.x, p[2] - patch.z) <= patch.radius
            #= none:7 =#
            value = max(value, Float64(patch.resistance))
        end
        #= none:9 =#
    end
    #= none:10 =#
    value
end
function ground_candidates(candidates, movement, load)
    #= none:13 =#
    #= none:14 =#
    out = deepcopy(candidates)
    #= none:15 =#
    for c = out
        #= none:16 =#
        c[NID(0x000000000000021f)] == NID(0x000000000000030d) || continue
        #= none:17 =#
        row = ((movement[NID(0x000000000000030b)])[NID(0x000000000000030c)])[c[NID(0x0000000000000251)] + 1]
        #= none:18 =#
        row[NID(0x000000000000030a)] === nothing && error(NID(0x000000000000037a))
        #= none:21 =#
        c[NID(0x00000000000002fc)] -= 0.25 * (row[NID(0x0000000000000231)] - 1.5) * (1 + 0.1load)
        #= none:22 =#
    end
    #= none:23 =#
    out
end
