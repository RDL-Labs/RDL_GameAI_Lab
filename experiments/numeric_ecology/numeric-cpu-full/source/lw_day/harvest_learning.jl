# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
harvest_state(actor) = begin
        #= none:3 =#
        D(NID(0x0000000000000259) => actor, NID(0x0000000000000288) => Any[], NID(0x0000000000000494) => D(), NID(0x000000000000008d) => nothing, NID(0x0000000000000633) => nothing, NID(0x0000000000000634) => nothing, NID(0x0000000000000635) => nothing, NID(0x00000000000002d6) => D(NID(0x00000000000002d7) => 0, NID(0x00000000000003dd) => 0), NID(0x00000000000002d9) => nothing)
    end
function harvest_section(move, source, now)
    #= none:7 =#
    #= none:8 =#
    food = [v for v = move[NID(0x00000000000001dd)] if v[NID(0x0000000000000330)] == NID(0x00000000000004ca)]
    #= none:9 =#
    D(NID(0x0000000000000121) => source, NID(0x00000000000002cc) => now, NID(0x000000000000034d) => true, NID(0x0000000000000636) => any((v[NID(0x0000000000000084)] <= 1.25 for v = food)), NID(0x00000000000003fc) => length(food))
end
function harvest_observe!(h, section)
    #= none:13 =#
    #= none:14 =#
    section[NID(0x000000000000034d)] || return
    #= none:15 =#
    if h[NID(0x0000000000000634)] === nothing
        #= none:16 =#
        h[NID(0x0000000000000634)] = deepcopy(section)
    elseif #= none:17 =# h[NID(0x0000000000000635)] === nothing && section[NID(0x00000000000003fc)] != (h[NID(0x0000000000000634)])[NID(0x00000000000003fc)]
        #= none:18 =#
        h[NID(0x0000000000000635)] = deepcopy(section)
    end
end
function harvest_result!(h, actor, operation, before, status, executed, after; accepted = true)
    #= none:22 =#
    #= none:23 =#
    check(accepted && actor == h[NID(0x0000000000000259)], NID(0x0000000000000637))
    #= none:24 =#
    check(before[NID(0x00000000000002cc)] < executed <= after[NID(0x00000000000002cc)], NID(0x0000000000000638))
    #= none:25 =#
    check(status in (NID(0x00000000000002e1), NID(0x0000000000000324)), NID(0x0000000000000639))
    #= none:26 =#
    r = D(NID(0x00000000000002f7) => operation, NID(0x00000000000002cb) => actor, NID(0x0000000000000158) => deepcopy(before), NID(0x0000000000000631) => deepcopy(after), NID(0x000000000000025a) => executed, NID(0x00000000000002e0) => status == NID(0x00000000000002e1), NID(0x000000000000063a) => after[NID(0x0000000000000636)])
    #= none:29 =#
    if haskey(h[NID(0x0000000000000494)], operation)
        #= none:30 =#
        check((h[NID(0x0000000000000494)])[operation] == r, NID(0x000000000000063b))
        #= none:30 =#
        return false
    end
    #= none:33 =#
    length(h[NID(0x0000000000000288)]) >= 6 && return false
    #= none:34 =#
    (h[NID(0x0000000000000494)])[operation] = r
    #= none:34 =#
    push!(h[NID(0x0000000000000288)], r)
    #= none:34 =#
    true
end
function freeze_harvest!(h, cycle, now)
    #= none:37 =#
    #= none:38 =#
    haskey(cycle, NID(0x000000000000063c)) && return
    #= none:39 =#
    cycle[NID(0x000000000000063c)] = now
    #= none:40 =#
    cycle[NID(0x0000000000000288)] = deepcopy([r for r = h[NID(0x0000000000000288)] if (r[NID(0x0000000000000631)])[NID(0x00000000000002cc)] <= now])
    #= none:41 =#
    cycle[NID(0x000000000000063d)] = deepcopy([h[NID(0x0000000000000634)], h[NID(0x0000000000000635)]])
    #= none:42 =#
    if get(h, NID(0x00000000000002c0), false)
        #= none:43 =#
        cycle[NID(0x000000000000063e)] = deepcopy([r for r = get(h, NID(0x000000000000063e), Any[]) if (r[NID(0x0000000000000631)])[NID(0x00000000000002cc)] <= now])
    end
end
function consolidate_harvest!(h, cycle, executed)
    #= none:47 =#
    #= none:48 =#
    if get(h, NID(0x00000000000002c0), false) && get(h, NID(0x000000000000063f), false)
        #= none:49 =#
        consolidate_replacement!(h, cycle, executed)
        #= none:49 =#
        return
    end
    #= none:51 =#
    rs = cycle[NID(0x0000000000000288)]
    #= none:51 =#
    reason = nothing
    #= none:52 =#
    status = if get(h, NID(0x000000000000063f), false)
            #= none:53 =#
            NID(0x0000000000000640)
        elseif #= none:54 =# h[NID(0x000000000000008d)] !== nothing
            #= none:55 =#
            NID(0x0000000000000641)
        elseif #= none:56 =# length(rs) < 5
            #= none:57 =#
            NID(0x000000000000058d)
        elseif #= none:58 =# h[NID(0x0000000000000633)] !== nothing && (h[NID(0x0000000000000633)])[NID(0x000000000000008a)] == NID(0x0000000000000642)
            #= none:59 =#
            NID(0x0000000000000643)
        elseif #= none:60 =# !(all(((r[NID(0x0000000000000158)])[NID(0x000000000000034d)] && (r[NID(0x0000000000000631)])[NID(0x000000000000034d)] for r = rs[1:5])))
            #= none:61 =#
            reason = NID(0x0000000000000644)
            #= none:61 =#
            NID(0x0000000000000645)
        elseif #= none:62 =# !(all(((r[NID(0x0000000000000158)])[NID(0x0000000000000636)] && (r[NID(0x00000000000002e0)] && r[NID(0x000000000000063a)]) for r = rs[1:5])))
            #= none:63 =#
            reason = NID(0x0000000000000646)
            #= none:63 =#
            NID(0x0000000000000642)
        elseif #= none:64 =# any((x === nothing for x = cycle[NID(0x000000000000063d)]))
            #= none:65 =#
            reason = NID(0x0000000000000647)
            #= none:65 =#
            NID(0x0000000000000645)
        else
            #= none:67 =#
            h[NID(0x000000000000008d)] = D(NID(0x000000000000008c) => NID(0x0000000000000648) * h[NID(0x0000000000000259)] * NID(0x00000000000000da) * ncat(cycle[NID(0x0000000000000173)]), NID(0x0000000000000330) => NID(0x00000000000004ca), NID(0x0000000000000467) => [r[NID(0x00000000000002f7)] for r = rs[1:3]], NID(0x0000000000000649) => [r[NID(0x00000000000002f7)] for r = rs[4:5]], NID(0x0000000000000479) => executed, NID(0x0000000000000191) => D(NID(0x00000000000002e0) => 1, NID(0x000000000000063a) => 1), NID(0x00000000000003f5) => NID(0x000000000000064a))
            #= none:72 =#
            NID(0x000000000000064b)
        end
    #= none:74 =#
    result = D(NID(0x000000000000008a) => status, NID(0x0000000000000364) => reason, NID(0x000000000000008c) => if h[NID(0x000000000000008d)] === nothing
                    nothing
                else
                    (h[NID(0x000000000000008d)])[NID(0x000000000000008c)]
                end)
    #= none:75 =#
    if !(status in (NID(0x0000000000000643), NID(0x0000000000000641), NID(0x0000000000000640)))
        #= none:76 =#
        h[NID(0x0000000000000633)] = deepcopy(result)
    end
    #= none:78 =#
    cycle[NID(0x0000000000000583)] = D(NID(0x000000000000008a) => NID(0x000000000000064c), NID(0x000000000000064d) => NID(0x000000000000064e))
    #= none:79 =#
    cycle[NID(0x00000000000003f9)] = result
end
function harvest_predict(h, section)
    #= none:82 =#
    #= none:83 =#
    known = !(get(h, NID(0x000000000000063f), false)) && (h[NID(0x000000000000008d)] !== nothing && (section[NID(0x000000000000034d)] && (section[NID(0x0000000000000636)] && section[NID(0x00000000000002cc)] >= (h[NID(0x000000000000008d)])[NID(0x0000000000000479)])))
    #= none:84 =#
    D(NID(0x000000000000008a) => if known
                NID(0x00000000000002d7)
            else
                NID(0x00000000000003dd)
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
