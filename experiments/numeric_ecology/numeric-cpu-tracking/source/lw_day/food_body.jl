# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
food_band(n) = begin
        #= none:2 =#
        if n == 0
            NID(0x0000000000000457)
        else
            if n <= 2
                NID(0x00000000000000df)
            else
                if n <= 5
                    NID(0x0000000000000458)
                else
                    NID(0x0000000000000459)
                end
            end
        end
    end
function metabolize(b, seconds)
    #= none:3 =#
    #= none:4 =#
    seconds >= 0 || error(NID(0x000000000000045a))
    #= none:5 =#
    Body(b.burst, b.strain, max(0.0, b.reserve - seconds * 0.25 * RS), b.damage)
end
hunger_state(actor) = begin
        #= none:7 =#
        D(NID(0x0000000000000259) => actor, NID(0x00000000000001e8) => 0, NID(0x000000000000013e) => 2, NID(0x00000000000000ce) => -1, NID(0x0000000000000314) => nothing, NID(0x000000000000045b) => 0.0, NID(0x000000000000045c) => 0, NID(0x000000000000028a) => Any[])
    end
function hunger_update!(h, actor, now, reserve)
    #= none:8 =#
    #= none:9 =#
    h[NID(0x0000000000000259)] == actor && (now >= h[NID(0x00000000000000ce)] && 0 <= reserve <= 100) || error(NID(0x000000000000045d))
    #= none:10 =#
    if h[NID(0x0000000000000314)] !== nothing && now >= h[NID(0x0000000000000314)]
        #= none:11 =#
        before = h[NID(0x00000000000001e8)]
        #= none:11 =#
        h[NID(0x00000000000001e8)] = if reserve > 80
                0
            else
                before + 1
            end
        #= none:11 =#
        h[NID(0x000000000000045c)] += 1
        #= none:12 =#
        push!(h[NID(0x000000000000028a)], D(NID(0x000000000000045e) => h[NID(0x0000000000000314)], NID(0x0000000000000121) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), actor), NID(0x000000000000014e) => reserve, NID(0x0000000000000444) => Int(reserve <= 80), NID(0x000000000000045f) => before, NID(0x0000000000000447) => h[NID(0x00000000000001e8)]))
        #= none:13 =#
        length(h[NID(0x000000000000028a)]) > 32 && popfirst!(h[NID(0x000000000000028a)])
        #= none:13 =#
        h[NID(0x0000000000000314)] = nothing
    end
    #= none:15 =#
    h[NID(0x0000000000000314)] === nothing && (reserve <= 80 && (h[NID(0x0000000000000314)] = now + 5000000))
    #= none:16 =#
    h[NID(0x00000000000000ce)] = now
    #= none:16 =#
    h[NID(0x000000000000045b)] = if reserve > 80
            0.0
        else
            0.05 + (0.95 * (80 - reserve)) / 80
        end
    #= none:17 =#
    h
end
hunger_select(h) = begin
        #= none:19 =#
        h[NID(0x000000000000045b)] > 0 && 0.2 + h[NID(0x000000000000045b)] + min(1.0, h[NID(0x00000000000001e8)] / h[NID(0x000000000000013e)]) > 0.5
    end
function retention_cost(obs, h)
    #= none:20 =#
    #= none:21 =#
    obs[NID(0x000000000000043f)] == h[NID(0x0000000000000259)] || error(NID(0x0000000000000460))
    #= none:22 =#
    scarcity = (Dict(NID(0x0000000000000457) => 0.0, NID(0x00000000000000df) => 1.0, NID(0x0000000000000458) => 0.4, NID(0x0000000000000459) => 0.0))[food_band(obs[NID(0x0000000000000081)])]
    #= none:23 =#
    reserve = (obs[NID(0x0000000000000080)])[NID(0x000000000000014e)]
    #= none:24 =#
    scarcity * (1 + 2 * max(0.0, (80 - reserve) / 80) + if reserve <= 80
                min(1.0, h[NID(0x00000000000001e8)] / h[NID(0x000000000000013e)])
            else
                0.0
            end)
end
function project_body_methods!(candidates, h, body, phase)
    #= none:28 =#
    #= none:29 =#
    phase in (NID(0x00000000000002d4), NID(0x00000000000002d5)) || return false
    #= none:30 =#
    urgency = h[NID(0x000000000000045b)] * (1 + min(1.0, h[NID(0x00000000000001e8)] / h[NID(0x000000000000013e)]))
    #= none:31 =#
    fatigue = body.strain
    #= none:31 =#
    recoverable = min(1.0, body.reserve / 20)
    #= none:31 =#
    applied = false
    #= none:32 =#
    for c = candidates
        #= none:33 =#
        get(c, NID(0x0000000000000461), true) || continue
        #= none:34 =#
        action = c[NID(0x000000000000021f)]
        #= none:35 =#
        delta = if action == NID(0x00000000000002f2)
                fatigue * recoverable - 0.5urgency
            else
                if action in (NID(0x000000000000030f), NID(0x000000000000030b))
                    0.5urgency - 0.5 * fatigue
                else
                    nothing
                end
            end
        #= none:36 =#
        delta === nothing && continue
        #= none:37 =#
        c[NID(0x00000000000002fe)] += delta
        #= none:37 =#
        applied |= delta != 0
        #= none:38 =#
    end
    #= none:39 =#
    applied
end
