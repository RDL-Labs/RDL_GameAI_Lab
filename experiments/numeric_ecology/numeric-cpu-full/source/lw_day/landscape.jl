# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
river_x(phase, z) = begin
        #= none:2 =#
        12 + 5 * sin((z - 6) / 22 + phase)
    end
river_width(z) = begin
        #= none:3 =#
        1.2 + 0.4 * (1 + sin(z / 13))
    end
function landscape_material(land, p)
    #= none:4 =#
    #= none:5 =#
    (x, z) = p
    #= none:5 =#
    d = abs(x - river_x(land.phase, z))
    #= none:6 =#
    d <= river_width(z) / 2 && return NID(0x00000000000002b3)
    #= none:7 =#
    d < 4 && return NID(0x00000000000003a6)
    #= none:8 =#
    (((x + 28) / 18) ^ 2 + ((z - 28) / 24) ^ 2 < 1 || ((x - 37) / 17) ^ 2 + ((z + 20) / 25) ^ 2 < 1) && return NID(0x00000000000003a7)
    #= none:9 =#
    ((x + 23) / 13) ^ 2 + ((z + 25) / 15) ^ 2 < 1 && return NID(0x00000000000003a8)
    #= none:10 =#
    NID(0x00000000000003a9)
end
function landscape_resistance(land, p)
    #= none:12 =#
    #= none:13 =#
    m = landscape_material(land, p)
    #= none:14 =#
    if m == NID(0x00000000000002b3)
        3.0
    else
        if m == NID(0x00000000000003a6)
            1.8
        else
            if m == NID(0x00000000000003a7)
                2.0
            else
                if m == NID(0x00000000000003a8)
                    2.5
                else
                    1.5
                end
            end
        end
    end
end
