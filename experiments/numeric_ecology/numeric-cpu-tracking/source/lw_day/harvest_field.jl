# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function harvest_field(candidates, move, h, actor, now; enabled = false, complete = true)
    #= none:2 =#
    #= none:3 =#
    check(h[NID(0x0000000000000259)] == actor, NID(0x0000000000000651))
    #= none:4 =#
    out = [copy(c) for c = candidates]
    #= none:5 =#
    trace = D(NID(0x000000000000008a) => NID(0x0000000000000652), NID(0x0000000000000289) => false, NID(0x0000000000000631) => Any[], NID(0x000000000000008c) => nothing, NID(0x0000000000000653) => 0.5, NID(0x00000000000001e6) => NID(0x0000000000000654))
    #= none:7 =#
    model = h[NID(0x000000000000008d)]
    #= none:7 =#
    model === nothing && return (out, trace)
    #= none:8 =#
    trace[NID(0x000000000000008c)] = model[NID(0x000000000000008c)]
    #= none:9 =#
    if get(h, NID(0x0000000000000641), false)
        #= none:10 =#
        trace[NID(0x000000000000008a)] = NID(0x0000000000000655)
        #= none:10 =#
        return (out, trace)
    end
    #= none:12 =#
    check((h[NID(0x0000000000000635)])[NID(0x000000000000008a)] == NID(0x000000000000064d), NID(0x0000000000000656))
    #= none:13 =#
    if now < model[NID(0x000000000000047b)] || !complete
        #= none:14 =#
        trace[NID(0x000000000000008a)] = NID(0x0000000000000657)
        #= none:14 =#
        return (out, trace)
    end
    #= none:16 =#
    visible = [v for v = move[NID(0x00000000000001dd)] if v[NID(0x0000000000000332)] == model[NID(0x0000000000000332)]]
    #= none:17 =#
    for c = out
        #= none:18 =#
        c[NID(0x000000000000021f)] == NID(0x000000000000030f) || continue
        #= none:19 =#
        index = c[NID(0x0000000000000251)]
        #= none:20 =#
        any((r[NID(0x0000000000000195)] == ncat(index) && r[NID(0x000000000000030c)] !== nothing for r = (move[NID(0x000000000000030d)])[NID(0x000000000000030e)])) || continue
        #= none:21 =#
        angle = deg2rad(Float64(ANGLES[index + 1]))
        #= none:24 =#
        value = min(0.5, sum((0.5 * max(0.0, cos(atan(v[NID(0x000000000000027c)], v[NID(0x000000000000027b)]) - angle)) for v = visible); init = 0.0))
        #= none:25 =#
        value > 0 || continue
        #= none:26 =#
        push!(trace[NID(0x0000000000000631)], D(NID(0x00000000000001b7) => c[NID(0x00000000000001b7)], NID(0x00000000000001b3) => value))
        #= none:27 =#
        enabled && (c[NID(0x00000000000002fe)] += value)
        #= none:28 =#
    end
    #= none:29 =#
    trace[NID(0x000000000000008a)] = if isempty(trace[NID(0x0000000000000631)])
            NID(0x0000000000000658)
        else
            if enabled
                NID(0x0000000000000289)
            else
                NID(0x00000000000002ae)
            end
        end
    #= none:30 =#
    trace[NID(0x0000000000000289)] = trace[NID(0x000000000000008a)] == NID(0x0000000000000289)
    #= none:31 =#
    (out, trace)
end
