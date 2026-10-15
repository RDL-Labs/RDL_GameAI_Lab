# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function replacement_result!(h, actor, op, before, status, executed, after; accepted = true, pose = true)
    #= none:3 =#
    #= none:4 =#
    check(accepted && actor == h[NID(0x0000000000000259)], NID(0x0000000000000669))
    #= none:5 =#
    get(h, NID(0x00000000000002c2), false) && (get(h, NID(0x0000000000000641), false) && !(get(h, NID(0x000000000000008e), false))) || return false
    #= none:6 =#
    check(before[NID(0x00000000000002ce)] < executed <= after[NID(0x00000000000002ce)], NID(0x000000000000066a))
    #= none:7 =#
    check(status in (NID(0x00000000000002e3), NID(0x0000000000000326)), NID(0x000000000000066b))
    #= none:8 =#
    inv = h[NID(0x0000000000000666)]
    #= none:10 =#
    get(inv[NID(0x0000000000000662)], NID(0x00000000000002e2), -1) == 0 && get(inv[NID(0x0000000000000662)], NID(0x000000000000063c), 0) != 0 || return false
    #= none:11 =#
    before[NID(0x00000000000002ce)] >= inv[NID(0x0000000000000664)] || return false
    #= none:12 =#
    op in vcat((h[NID(0x000000000000008d)])[NID(0x0000000000000469)], (h[NID(0x000000000000008d)])[NID(0x000000000000064b)], [inv[NID(0x0000000000000328)]]) && return false
    #= none:13 =#
    r = D(NID(0x00000000000002f9) => op, NID(0x00000000000002cd) => actor, NID(0x0000000000000158) => deepcopy(before), NID(0x0000000000000633) => deepcopy(after), NID(0x000000000000025a) => executed, NID(0x00000000000002e2) => status == NID(0x00000000000002e3), NID(0x000000000000018c) => pose)
    #= none:15 =#
    rows = get!(h, NID(0x0000000000000640), Any[])
    #= none:16 =#
    prior = findfirst((x->begin
                    #= none:16 =#
                    x[NID(0x00000000000002f9)] == op
                end), rows)
    #= none:17 =#
    if prior !== nothing
        #= none:18 =#
        check(rows[prior] == r, NID(0x000000000000066c))
        #= none:18 =#
        return false
    end
    #= none:20 =#
    length(rows) >= 6 && return false
    #= none:21 =#
    push!(rows, r)
    #= none:21 =#
    true
end
function consolidate_replacement!(h, c, now)
    #= none:24 =#
    #= none:25 =#
    rows = get(c, NID(0x0000000000000640), Any[])
    #= none:26 =#
    result = if get(h, NID(0x000000000000008e), false)
            #= none:27 =#
            NID(0x0000000000000642)
        elseif #= none:28 =# length(rows) < 5
            #= none:29 =#
            NID(0x000000000000066d)
        elseif #= none:30 =# !(all(((r[NID(0x0000000000000158)])[NID(0x000000000000034f)] && ((r[NID(0x0000000000000633)])[NID(0x000000000000034f)] && r[NID(0x000000000000018c)]) for r = rows[1:5])))
            #= none:31 =#
            NID(0x000000000000066e)
        elseif #= none:32 =# !(all(((r[NID(0x0000000000000158)])[NID(0x0000000000000638)] && r[NID(0x00000000000002e2)] for r = rows[1:5])))
            #= none:33 =#
            NID(0x000000000000066f)
        else
            #= none:35 =#
            old = deepcopy(h[NID(0x000000000000008d)])
            #= none:36 =#
            h[NID(0x0000000000000670)] = old
            #= none:36 =#
            h[NID(0x0000000000000671)] = deepcopy(h[NID(0x0000000000000635)])
            #= none:37 =#
            h[NID(0x000000000000008d)] = D(NID(0x000000000000008c) => NID(0x0000000000000672) * h[NID(0x0000000000000259)] * NID(0x00000000000000da) * ncat(c[NID(0x0000000000000173)]), NID(0x0000000000000332) => old[NID(0x0000000000000332)], NID(0x000000000000047b) => now, NID(0x0000000000000191) => D(NID(0x00000000000002e2) => 1), NID(0x0000000000000469) => [r[NID(0x00000000000002f9)] for r = rows[1:3]], NID(0x000000000000064b) => [r[NID(0x00000000000002f9)] for r = rows[4:5]], NID(0x0000000000000673) => old[NID(0x000000000000008c)], NID(0x00000000000003f7) => NID(0x0000000000000674))
            #= none:41 =#
            h[NID(0x0000000000000635)] = D(NID(0x000000000000008a) => NID(0x000000000000064d), NID(0x000000000000008c) => (h[NID(0x000000000000008d)])[NID(0x000000000000008c)])
            #= none:42 =#
            h[NID(0x0000000000000641)] = false
            #= none:42 =#
            h[NID(0x000000000000008e)] = true
            #= none:43 =#
            NID(0x0000000000000675)
        end
    #= none:45 =#
    c[NID(0x0000000000000585)] = D(NID(0x000000000000008a) => NID(0x0000000000000676), NID(0x000000000000064f) => NID(0x0000000000000650))
    #= none:46 =#
    c[NID(0x00000000000003fb)] = D(NID(0x000000000000008a) => result, NID(0x000000000000008c) => (h[NID(0x000000000000008d)])[NID(0x000000000000008c)], NID(0x0000000000000366) => nothing)
end
