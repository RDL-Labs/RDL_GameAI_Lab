# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
return_purpose() = begin
        #= none:2 =#
        D(NID(0x00000000000001bc) => false, NID(0x0000000000000429) => nothing, NID(0x000000000000034e) => 0, NID(0x0000000000000162) => 0)
    end
function returning!(s, phase, load, at_home, now)
    #= none:3 =#
    #= none:4 =#
    if s[NID(0x00000000000001bc)] && (at_home && load == 0)
        #= none:5 =#
        s[NID(0x00000000000001bc)] = false
        #= none:5 =#
        s[NID(0x0000000000000162)] += 1
    end
    #= none:7 =#
    triggered = phase in (NID(0x00000000000002d3), NID(0x00000000000002d4)) || load >= 6
    #= none:8 =#
    if !(s[NID(0x00000000000001bc)]) && (triggered && (!at_home || load > 0))
        #= none:9 =#
        s[NID(0x00000000000001bc)] = true
        #= none:9 =#
        s[NID(0x0000000000000429)] = now
        #= none:9 =#
        s[NID(0x000000000000034e)] += 1
    end
    #= none:12 =#
    s[NID(0x00000000000001bc)] || triggered
end
