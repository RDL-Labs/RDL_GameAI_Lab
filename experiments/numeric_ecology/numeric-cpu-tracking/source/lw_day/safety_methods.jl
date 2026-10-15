# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
threat_band(features) = begin
        #= none:2 =#
        if isempty(features)
            3
        else
            minimum((if h[NID(0x0000000000000084)] <= 4
                    0
                else
                    if h[NID(0x0000000000000084)] <= 8
                        1
                    else
                        2
                    end
                end for h = features))
        end
    end
function limited_clearance!(state, ob)
    #= none:6 =#
    #= none:7 =#
    fs = ob[NID(0x0000000000000341)]
    #= none:7 =#
    complete = ob[NID(0x000000000000034e)] == NID(0x000000000000034f)
    #= none:8 =#
    state[NID(0x00000000000005d5)] = if complete && (!(isempty(fs)) && threat_band(fs) == 2)
            get(state, NID(0x00000000000005d5), 0) + 1
        else
            0
        end
    #= none:9 =#
    result = get(state, NID(0x000000000000032d), nothing)
    #= none:10 =#
    linked = get(state, NID(0x000000000000032c), false) && result !== nothing
    #= none:11 =#
    if complete && (isempty(fs) && (linked && (result.action == NID(0x000000000000030b) && (result.status == NID(0x000000000000029b) && abs(abs(result.yaw) - 90) < 0.01))))
        #= none:12 =#
        state[NID(0x00000000000005d6)] = get(state, NID(0x00000000000005d6), 0.0) + result.yaw
    elseif #= none:13 =# !(isempty(fs)) || (!complete || (!linked || result.action in (NID(0x000000000000030f), NID(0x000000000000031c), NID(0x000000000000030b))))
        #= none:14 =#
        state[NID(0x00000000000005d6)] = 0.0
    end
    #= none:16 =#
    if state[NID(0x00000000000005d5)] >= 2 || abs(get(state, NID(0x00000000000005d6), 0.0)) >= 360
        #= none:17 =#
        state[NID(0x00000000000001bc)] = false
        #= none:17 =#
        state[NID(0x0000000000000351)] += 1
        #= none:18 =#
        state[NID(0x00000000000005d7)] = get(state, NID(0x00000000000005d7), 0) + 1
        #= none:19 =#
        state[NID(0x00000000000005d8)] = NID(0x00000000000005d9)
        #= none:20 =#
        state[NID(0x00000000000005d6)] = 0.0
        #= none:20 =#
        state[NID(0x00000000000005d5)] = 0
        #= none:21 =#
        return true
    end
    #= none:23 =#
    false
end
function safety_methods!(state, loop, ob, movement, source; running = false)
    #= none:25 =#
    #= none:26 =#
    fs = ob[NID(0x0000000000000341)]
    #= none:26 =#
    band = threat_band(fs)
    #= none:27 =#
    if loop.trial !== nothing
        #= none:28 =#
        prior = state[NID(0x00000000000005da)]
        #= none:29 =#
        comparable = get(state, NID(0x000000000000032c), false)
        #= none:30 =#
        value = if comparable
                !(isempty(fs)) && band > prior || isempty(fs) && ob[NID(0x000000000000034e)] == NID(0x000000000000034f)
            else
                nothing
            end
        #= none:31 =#
        resolve_method!(loop, loop.trial.source, value, value)
    end
    #= none:35 =#
    if !(state[NID(0x00000000000001bc)]) && band >= 2
        #= none:36 =#
        return nothing
    end
    #= none:38 =#
    if state[NID(0x00000000000001bc)]
        #= none:39 =#
        limited_clearance!(state, ob) && return nothing
    else
        #= none:41 =#
        state[NID(0x00000000000005d6)] = 0.0
        #= none:41 =#
        state[NID(0x00000000000005d5)] = 0
    end
    #= none:43 =#
    if !(isempty(fs))
        #= none:44 =#
        !(state[NID(0x00000000000001bc)]) && (state[NID(0x0000000000000350)] += 1)
        #= none:45 =#
        state[NID(0x00000000000001bc)] = true
        #= none:45 =#
        state[NID(0x00000000000001e8)] = 0
    else
        #= none:47 =#
        get(state, NID(0x000000000000032c), false) && (state[NID(0x00000000000001e8)] = min(8, state[NID(0x00000000000001e8)] + if ob[NID(0x000000000000034e)] == NID(0x000000000000034f)
                            2
                        else
                            1
                        end))
        #= none:48 =#
        if state[NID(0x00000000000001e8)] >= 8
            #= none:49 =#
            state[NID(0x00000000000001bc)] = false
            #= none:49 =#
            state[NID(0x0000000000000351)] += 1
            #= none:49 =#
            state[NID(0x00000000000005d8)] = NID(0x00000000000005db)
            #= none:49 =#
            return nothing
        end
    end
    #= none:52 =#
    candidates = Any[D(NID(0x00000000000001b7) => NID(0x0000000000000322), NID(0x000000000000021f) => NID(0x00000000000002f2), NID(0x00000000000002fe) => if isempty(fs)
                        1.0
                    else
                        2.0
                    end, NID(0x00000000000001b4) => NID(0x00000000000005dc)), D(NID(0x00000000000001b7) => NID(0x00000000000005dd), NID(0x000000000000021f) => NID(0x000000000000030b), NID(0x0000000000000311) => -90, NID(0x00000000000002fe) => 1.5, NID(0x00000000000001b4) => NID(0x00000000000005dc)), D(NID(0x00000000000001b7) => NID(0x00000000000005de), NID(0x000000000000021f) => NID(0x000000000000030b), NID(0x0000000000000311) => 90, NID(0x00000000000002fe) => 1.5, NID(0x00000000000001b4) => NID(0x00000000000005dc))]
    #= none:55 =#
    rows = copy((movement[NID(0x000000000000030d)])[NID(0x000000000000030e)])
    #= none:56 =#
    running && append!(rows, movement[NID(0x000000000000031f)])
    #= none:57 =#
    for row = rows
        #= none:58 =#
        row[NID(0x000000000000030c)] === nothing && continue
        #= none:59 =#
        i = parse(Int, row[NID(0x0000000000000195)])
        #= none:59 =#
        angle = deg2rad(ANGLES[i + 1])
        #= none:60 =#
        i == 2 && (any((h->begin
                            #= none:60 =#
                            h[NID(0x0000000000000084)] <= 4 && abs(rad2deg(atan(h[NID(0x000000000000027c)], h[NID(0x000000000000027b)]))) < 30
                        end), fs) && continue)
        #= none:62 =#
        pressure = if isempty(fs)
                0.0
            else
                maximum((cos(angle - atan(h[NID(0x000000000000027c)], h[NID(0x000000000000027b)])) for h = fs))
            end
        #= none:63 =#
        action = get(row, NID(0x000000000000021f), NID(0x000000000000030f))
        #= none:64 =#
        effort = get(row, NID(0x0000000000000231), 1.5) * (1 + 0.1 * get(row, NID(0x0000000000000318), 0))
        #= none:65 =#
        score = (2 - 1.5pressure) - 0.05 * effort * if action == NID(0x000000000000031c)
                        5
                    else
                        1
                    end
        #= none:66 =#
        push!(candidates, D(NID(0x00000000000001b7) => action * ncat(NID(0x00000000000001d6), ANGLES[i + 1]), NID(0x000000000000021f) => action, NID(0x0000000000000251) => i, NID(0x00000000000002fe) => score, NID(0x00000000000001b4) => NID(0x00000000000005dc)))
        #= none:67 =#
    end
    #= none:68 =#
    plan = choose_method!(loop, candidates, source)
    #= none:68 =#
    plan[NID(0x000000000000007b)] = true
    #= none:69 =#
    state[NID(0x00000000000005da)] = band
    #= none:69 =#
    state[NID(0x000000000000032c)] = false
    #= none:69 =#
    state[NID(0x0000000000000352)] += 1
    #= none:70 =#
    plan
end
