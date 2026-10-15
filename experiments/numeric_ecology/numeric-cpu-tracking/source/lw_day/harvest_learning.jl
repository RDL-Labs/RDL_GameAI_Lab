# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
harvest_state(actor) = begin
        #= none:3 =#
        D(NID(0x0000000000000259) => actor, NID(0x000000000000028a) => Any[], NID(0x0000000000000496) => D(), NID(0x000000000000008d) => nothing, NID(0x0000000000000635) => nothing, NID(0x0000000000000636) => nothing, NID(0x0000000000000637) => nothing, NID(0x00000000000002d8) => D(NID(0x00000000000002d9) => 0, NID(0x00000000000003df) => 0), NID(0x00000000000002db) => nothing)
    end
function harvest_section(move, source, now)
    #= none:7 =#
    #= none:8 =#
    food = [v for v = move[NID(0x00000000000001dd)] if v[NID(0x0000000000000332)] == NID(0x00000000000004cc)]
    #= none:9 =#
    D(NID(0x0000000000000121) => source, NID(0x00000000000002ce) => now, NID(0x000000000000034f) => true, NID(0x0000000000000638) => any((v[NID(0x0000000000000084)] <= 1.25 for v = food)), NID(0x00000000000003fe) => length(food))
end
function harvest_observe!(h, section)
    #= none:13 =#
    #= none:14 =#
    section[NID(0x000000000000034f)] || return
    #= none:15 =#
    if h[NID(0x0000000000000636)] === nothing
        #= none:16 =#
        h[NID(0x0000000000000636)] = deepcopy(section)
    elseif #= none:17 =# h[NID(0x0000000000000637)] === nothing && section[NID(0x00000000000003fe)] != (h[NID(0x0000000000000636)])[NID(0x00000000000003fe)]
        #= none:18 =#
        h[NID(0x0000000000000637)] = deepcopy(section)
    end
end
function harvest_result!(h, actor, operation, before, status, executed, after; accepted = true)
    #= none:22 =#
    #= none:23 =#
    check(accepted && actor == h[NID(0x0000000000000259)], NID(0x0000000000000639))
    #= none:24 =#
    check(before[NID(0x00000000000002ce)] < executed <= after[NID(0x00000000000002ce)], NID(0x000000000000063a))
    #= none:25 =#
    check(status in (NID(0x00000000000002e3), NID(0x0000000000000326)), NID(0x000000000000063b))
    #= none:26 =#
    r = D(NID(0x00000000000002f9) => operation, NID(0x00000000000002cd) => actor, NID(0x0000000000000158) => deepcopy(before), NID(0x0000000000000633) => deepcopy(after), NID(0x000000000000025a) => executed, NID(0x00000000000002e2) => status == NID(0x00000000000002e3), NID(0x000000000000063c) => after[NID(0x0000000000000638)])
    #= none:29 =#
    if haskey(h[NID(0x0000000000000496)], operation)
        #= none:30 =#
        check((h[NID(0x0000000000000496)])[operation] == r, NID(0x000000000000063d))
        #= none:30 =#
        return false
    end
    #= none:33 =#
    length(h[NID(0x000000000000028a)]) >= 6 && return false
    #= none:34 =#
    (h[NID(0x0000000000000496)])[operation] = r
    #= none:34 =#
    push!(h[NID(0x000000000000028a)], r)
    #= none:34 =#
    true
end
function freeze_harvest!(h, cycle, now)
    #= none:37 =#
    #= none:38 =#
    haskey(cycle, NID(0x000000000000063e)) && return
    #= none:39 =#
    cycle[NID(0x000000000000063e)] = now
    #= none:40 =#
    cycle[NID(0x000000000000028a)] = deepcopy([r for r = h[NID(0x000000000000028a)] if (r[NID(0x0000000000000633)])[NID(0x00000000000002ce)] <= now])
    #= none:41 =#
    cycle[NID(0x000000000000063f)] = deepcopy([h[NID(0x0000000000000636)], h[NID(0x0000000000000637)]])
    #= none:42 =#
    if get(h, NID(0x00000000000002c2), false)
        #= none:43 =#
        cycle[NID(0x0000000000000640)] = deepcopy([r for r = get(h, NID(0x0000000000000640), Any[]) if (r[NID(0x0000000000000633)])[NID(0x00000000000002ce)] <= now])
    end
end
function consolidate_harvest!(h, cycle, executed)
    #= none:47 =#
    #= none:48 =#
    if get(h, NID(0x00000000000002c2), false) && get(h, NID(0x0000000000000641), false)
        #= none:49 =#
        consolidate_replacement!(h, cycle, executed)
        #= none:49 =#
        return
    end
    #= none:51 =#
    rs = cycle[NID(0x000000000000028a)]
    #= none:51 =#
    reason = nothing
    #= none:52 =#
    status = if get(h, NID(0x0000000000000641), false)
            #= none:53 =#
            NID(0x0000000000000642)
        elseif #= none:54 =# h[NID(0x000000000000008d)] !== nothing
            #= none:55 =#
            NID(0x0000000000000643)
        elseif #= none:56 =# length(rs) < 5
            #= none:57 =#
            NID(0x000000000000058f)
        elseif #= none:58 =# h[NID(0x0000000000000635)] !== nothing && (h[NID(0x0000000000000635)])[NID(0x000000000000008a)] == NID(0x0000000000000644)
            #= none:59 =#
            NID(0x0000000000000645)
        elseif #= none:60 =# !(all(((r[NID(0x0000000000000158)])[NID(0x000000000000034f)] && (r[NID(0x0000000000000633)])[NID(0x000000000000034f)] for r = rs[1:5])))
            #= none:61 =#
            reason = NID(0x0000000000000646)
            #= none:61 =#
            NID(0x0000000000000647)
        elseif #= none:62 =# !(all(((r[NID(0x0000000000000158)])[NID(0x0000000000000638)] && (r[NID(0x00000000000002e2)] && r[NID(0x000000000000063c)]) for r = rs[1:5])))
            #= none:63 =#
            reason = NID(0x0000000000000648)
            #= none:63 =#
            NID(0x0000000000000644)
        elseif #= none:64 =# any((x === nothing for x = cycle[NID(0x000000000000063f)]))
            #= none:65 =#
            reason = NID(0x0000000000000649)
            #= none:65 =#
            NID(0x0000000000000647)
        else
            #= none:67 =#
            h[NID(0x000000000000008d)] = D(NID(0x000000000000008c) => NID(0x000000000000064a) * h[NID(0x0000000000000259)] * NID(0x00000000000000da) * ncat(cycle[NID(0x0000000000000173)]), NID(0x0000000000000332) => NID(0x00000000000004cc), NID(0x0000000000000469) => [r[NID(0x00000000000002f9)] for r = rs[1:3]], NID(0x000000000000064b) => [r[NID(0x00000000000002f9)] for r = rs[4:5]], NID(0x000000000000047b) => executed, NID(0x0000000000000191) => D(NID(0x00000000000002e2) => 1, NID(0x000000000000063c) => 1), NID(0x00000000000003f7) => NID(0x000000000000064c))
            #= none:72 =#
            NID(0x000000000000064d)
        end
    #= none:74 =#
    result = D(NID(0x000000000000008a) => status, NID(0x0000000000000366) => reason, NID(0x000000000000008c) => if h[NID(0x000000000000008d)] === nothing
                    nothing
                else
                    (h[NID(0x000000000000008d)])[NID(0x000000000000008c)]
                end)
    #= none:75 =#
    if !(status in (NID(0x0000000000000645), NID(0x0000000000000643), NID(0x0000000000000642)))
        #= none:76 =#
        h[NID(0x0000000000000635)] = deepcopy(result)
    end
    #= none:78 =#
    cycle[NID(0x0000000000000585)] = D(NID(0x000000000000008a) => NID(0x000000000000064e), NID(0x000000000000064f) => NID(0x0000000000000650))
    #= none:79 =#
    cycle[NID(0x00000000000003fb)] = result
end
function harvest_predict(h, section)
    #= none:82 =#
    #= none:83 =#
    known = !(get(h, NID(0x0000000000000641), false)) && (h[NID(0x000000000000008d)] !== nothing && (section[NID(0x000000000000034f)] && (section[NID(0x0000000000000638)] && section[NID(0x00000000000002ce)] >= (h[NID(0x000000000000008d)])[NID(0x000000000000047b)])))
    #= none:84 =#
    D(NID(0x000000000000008a) => if known
                NID(0x00000000000002d9)
            else
                NID(0x00000000000003df)
            end, NID(0x000000000000004e) => if known
                deepcopy((h[NID(0x000000000000008d)])[NID(0x0000000000000191)])
            else
                nothing
            end, NID(0x000000000000008c) => if h[NID(0x000000000000008d)] === nothing
                nothing
            else
                (h[NID(0x000000000000008d)])[NID(0x000000000000008c)]
            end, NID(0x0000000000000121) => section[NID(0x0000000000000121)])
end
