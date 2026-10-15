# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
repetition_state() = begin
        #= none:2 =#
        D(NID(0x00000000000005cd) => D(), NID(0x0000000000000130) => nothing, NID(0x00000000000000ce) => -1, NID(0x00000000000005ce) => 0, NID(0x00000000000005cf) => 0, NID(0x0000000000000300) => 0)
    end
function repetition_result!(s, source, now, method, view; changed = false, decay = 0.1)
    #= none:3 =#
    #= none:4 =#
    check(isfinite(decay) && decay >= 0, NID(0x00000000000005d0))
    #= none:5 =#
    check(now > s[NID(0x00000000000000ce)], NID(0x00000000000005d1))
    #= none:6 =#
    dt = if s[NID(0x00000000000000ce)] < 0
            0.0
        else
            (now - s[NID(0x00000000000000ce)]) / 1.0e6
        end
    #= none:7 =#
    for k = keys(s[NID(0x00000000000005cd)])
        #= none:7 =#
        (s[NID(0x00000000000005cd)])[k] = max(0.0, (s[NID(0x00000000000005cd)])[k] - decay * dt)
        #= none:7 =#
    end
    #= none:8 =#
    prior = s[NID(0x0000000000000130)]
    #= none:9 =#
    if method !== nothing && (!changed && (prior !== nothing && (prior.method == method && prior.view == view)))
        #= none:10 =#
        if haskey(s[NID(0x00000000000005cd)], method) || length(s[NID(0x00000000000005cd)]) < 64
            #= none:11 =#
            (s[NID(0x00000000000005cd)])[method] = min(32.0, get(s[NID(0x00000000000005cd)], method, 0.0) + 1.0)
            #= none:12 =#
            s[NID(0x00000000000005ce)] += 1
        end
    end
    #= none:15 =#
    s[NID(0x0000000000000130)] = if method === nothing
            nothing
        else
            (method = method, view = view, source = source)
        end
    #= none:16 =#
    s[NID(0x00000000000000ce)] = now
end
function project_repetition!(s, candidates)
    #= none:18 =#
    #= none:19 =#
    applied = false
    #= none:20 =#
    for c = candidates
        #= none:21 =#
        h = get(s[NID(0x00000000000005cd)], c[NID(0x00000000000001b7)], 0.0)
        #= none:22 =#
        if h >= 4.0
            #= none:23 =#
            c[NID(0x00000000000002fe)] -= min(4.0, h / 4.0)
            #= none:24 =#
            applied = true
        end
        #= none:26 =#
    end
    #= none:27 =#
    s[NID(0x00000000000005cf)] += Int(applied)
    #= none:28 =#
    applied
end
