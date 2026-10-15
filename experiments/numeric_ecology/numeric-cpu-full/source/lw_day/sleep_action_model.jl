# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
sleep_action_state(owner) = begin
        #= none:2 =#
        D(NID(0x0000000000000351) => owner, NID(0x0000000000000288) => D(), NID(0x00000000000004a2) => nothing, NID(0x00000000000004a3) => 0, NID(0x00000000000002c1) => 0)
    end
function sleep_context(move, hazard; climbs = nothing)
    #= none:3 =#
    #= none:4 =#
    get(move, NID(0x0000000000000381), nothing) == NID(0x000000000000034d) && hazard[NID(0x000000000000034c)] == NID(0x000000000000034d) || return nothing
    #= none:5 =#
    rows = (move[NID(0x000000000000030b)])[NID(0x000000000000030c)]
    #= none:6 =#
    context = Any[!(isempty(move[NID(0x00000000000001dd)])), !(isempty(hazard[NID(0x000000000000033f)])), Any[Any[r[NID(0x0000000000000195)], r[NID(0x0000000000000316)], r[NID(0x000000000000008a)], r[NID(0x0000000000000231)]] for r = rows]]
    #= none:8 =#
    if haskey(move, NID(0x000000000000031d))
        #= none:9 =#
        push!(context, Any[NID(0x000000000000031a), Any[Any[r[NID(0x000000000000008a)], r[NID(0x0000000000000316)], r[NID(0x0000000000000231)]] for r = move[NID(0x000000000000031d)]]])
    end
    #= none:11 =#
    if climbs !== nothing
        #= none:12 =#
        push!(context, Any[NID(0x0000000000000315), Any[Any[r[NID(0x0000000000000251)], r[NID(0x0000000000000318)], r[NID(0x00000000000000ac)], r[NID(0x000000000000008a)], r[NID(0x0000000000000316)], r[NID(0x0000000000000231)], r[NID(0x000000000000041d)], r[NID(0x000000000000041e)]] for r = climbs]])
    end
    #= none:14 =#
    context
end
function adopt_sleep_actions!(s, review, owner, now)
    #= none:16 =#
    #= none:17 =#
    check(s[NID(0x0000000000000351)] == owner, NID(0x00000000000004a4))
    #= none:18 =#
    staged = copy(s[NID(0x0000000000000288)])
    #= none:19 =#
    for r = review[NID(0x0000000000000288)]
        #= none:20 =#
        check(r[NID(0x0000000000000259)] == owner && r[NID(0x000000000000025a)] <= review[NID(0x000000000000032d)] < now, NID(0x00000000000004a5))
        #= none:21 =#
        if haskey(staged, r[NID(0x0000000000000237)])
            #= none:22 =#
            check(staged[r[NID(0x0000000000000237)]] == r, NID(0x00000000000004a6))
        else
            #= none:24 =#
            staged[r[NID(0x0000000000000237)]] = deepcopy(r)
        end
        #= none:26 =#
    end
    #= none:27 =#
    check(length(staged) <= 192, NID(0x00000000000004a7))
    #= none:28 =#
    s[NID(0x0000000000000288)] = staged
    #= none:28 =#
    s[NID(0x00000000000004a2)] = now
end
function project_sleep_actions!(s, candidates, context, owner, now)
    #= none:30 =#
    #= none:31 =#
    check(s[NID(0x0000000000000351)] == owner, NID(0x00000000000004a4))
    #= none:32 =#
    context === nothing && return false
    #= none:33 =#
    s[NID(0x00000000000004a2)] === nothing && return false
    #= none:34 =#
    s[NID(0x00000000000004a2)] >= now && return false
    #= none:35 =#
    applied = false
    #= none:36 =#
    for c = candidates
        #= none:37 =#
        c[NID(0x000000000000021f)] in (NID(0x000000000000030d), NID(0x0000000000000309), NID(0x000000000000031a), NID(0x0000000000000315), NID(0x00000000000002f0)) || continue
        #= none:38 =#
        group = [r for r = values(s[NID(0x0000000000000288)]) if (!(haskey(s, NID(0x00000000000004a8))) || !((((s[NID(0x00000000000004a8)])[NID(0x000000000000046e)])[r[NID(0x0000000000000237)]])[NID(0x0000000000000469)])) && (get(r, NID(0x0000000000000250), nothing) == context && (r[NID(0x000000000000021f)] == c[NID(0x000000000000021f)] && (get(r, NID(0x0000000000000251), nothing) == get(c, NID(0x0000000000000251), nothing) && r[NID(0x0000000000000334)] in (NID(0x0000000000000299), NID(0x000000000000036a)))))]
        #= none:41 =#
        isempty(group) && continue
        #= none:42 =#
        if haskey(s, NID(0x00000000000004a8))
            #= none:43 =#
            c[NID(0x00000000000004a9)] = [r[NID(0x0000000000000237)] for r = group]
            #= none:44 =#
            for r = group
                #= none:44 =#
                (((s[NID(0x00000000000004a8)])[NID(0x000000000000046e)])[r[NID(0x0000000000000237)]])[NID(0x000000000000047b)] += 1
                #= none:44 =#
            end
        end
        #= none:46 =#
        rate = count((r->begin
                            #= none:46 =#
                            r[NID(0x0000000000000334)] == NID(0x0000000000000299)
                        end), group) / length(group)
        #= none:47 =#
        c[NID(0x00000000000002fc)] += 0.75 * (2rate - 1)
        #= none:47 =#
        applied = true
        #= none:48 =#
    end
    #= none:49 =#
    applied && (s[NID(0x00000000000004a3)] += 1)
    #= none:50 =#
    applied
end
