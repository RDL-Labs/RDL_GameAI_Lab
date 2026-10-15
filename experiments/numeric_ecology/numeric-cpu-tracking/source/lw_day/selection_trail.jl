# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
selection_trail_state(actor) = begin
        #= none:2 =#
        D(NID(0x0000000000000259) => actor, NID(0x0000000000000485) => D(), NID(0x000000000000048a) => nothing, NID(0x0000000000000162) => Any[], NID(0x000000000000048b) => nothing, NID(0x0000000000000300) => 0)
    end
trail_key(s, context, phase, c) = begin
        #= none:3 =#
        njson(Any[s[NID(0x0000000000000259)] * NID(0x000000000000048c), context, phase, c[NID(0x00000000000001b7)], Any[c[NID(0x000000000000021f)], get(c, NID(0x0000000000000251), nothing), get(c, NID(0x0000000000000311), nothing)]])
    end
function project_trails!(s, candidates, loop, context, phase)
    #= none:4 =#
    #= none:5 =#
    phase in (NID(0x00000000000002d4), NID(0x00000000000002d5)) || return nothing
    #= none:6 =#
    baseline = (method_choice(loop, candidates))[NID(0x00000000000001b7)]
    #= none:6 =#
    edges = D()
    #= none:7 =#
    for c = candidates
        #= none:8 =#
        get(c, NID(0x0000000000000461), true) || continue
        #= none:9 =#
        key = trail_key(s, context, phase, c)
        #= none:9 =#
        e = get(s[NID(0x0000000000000485)], key, D())
        #= none:10 =#
        c[NID(0x00000000000002fe)] += min(1.0, get(e, NID(0x000000000000047c), 0) * 0.02) + min(1.0, get(e, NID(0x000000000000048d), 0.0) * 0.125)
        #= none:11 =#
        edges[c[NID(0x00000000000001b7)]] = key
        #= none:12 =#
    end
    #= none:13 =#
    selected = (method_choice(loop, candidates))[NID(0x00000000000001b7)]
    #= none:14 =#
    D(NID(0x0000000000000485) => edges, NID(0x0000000000000304) => selected, NID(0x0000000000000256) => baseline != selected)
end
function use_trail!(s, actor, op, trace, method, status, reserve, H, refs)
    #= none:16 =#
    #= none:17 =#
    actor == s[NID(0x0000000000000259)] || error(NID(0x000000000000048e))
    #= none:18 =#
    op == s[NID(0x000000000000048b)] && return false
    #= none:19 =#
    s[NID(0x000000000000048b)] = op
    #= none:20 =#
    trace === nothing && return false
    #= none:21 =#
    haskey(trace[NID(0x0000000000000485)], method) && !(status in (NID(0x0000000000000478), NID(0x0000000000000479), NID(0x000000000000030a))) || return false
    #= none:22 =#
    key = (trace[NID(0x0000000000000485)])[method]
    #= none:23 =#
    if !(haskey(s[NID(0x0000000000000485)], key)) && length(s[NID(0x0000000000000485)]) >= 512
        #= none:24 =#
        s[NID(0x0000000000000477)] = true
        #= none:24 =#
        return false
    end
    #= none:26 =#
    e = get!(s[NID(0x0000000000000485)], key, D(NID(0x000000000000047c) => 0, NID(0x000000000000048d) => 0.0, NID(0x000000000000048f) => 0))
    #= none:27 =#
    e[NID(0x000000000000047c)] += 1
    #= none:27 =#
    e[NID(0x0000000000000490)] = op
    #= none:28 =#
    trace[NID(0x0000000000000256)] && (method == trace[NID(0x0000000000000304)] && (s[NID(0x0000000000000300)] += 1))
    #= none:29 =#
    if reserve <= 80
        #= none:30 =#
        s[NID(0x000000000000048a)] === nothing && (s[NID(0x000000000000048a)] = D(NID(0x0000000000000342) => op, NID(0x0000000000000485) => D(), NID(0x0000000000000491) => 0))
        #= none:31 =#
        ep = s[NID(0x000000000000048a)]
        #= none:31 =#
        ep[NID(0x0000000000000491)] = max(ep[NID(0x0000000000000491)], H)
        #= none:32 =#
        entry = get!(ep[NID(0x0000000000000485)], key, D(NID(0x0000000000000492) => op, NID(0x000000000000047c) => 0, NID(0x0000000000000493) => NID[]))
        #= none:33 =#
        entry[NID(0x000000000000047c)] += 1
        #= none:33 =#
        entry[NID(0x0000000000000493)] = sort(unique(vcat(entry[NID(0x0000000000000493)], refs)))
    end
    #= none:35 =#
    true
end
function resolve_trail!(s, actor, reserve, source, now)
    #= none:37 =#
    #= none:38 =#
    actor == s[NID(0x0000000000000259)] || error(NID(0x000000000000048e))
    #= none:39 =#
    ep = s[NID(0x000000000000048a)]
    #= none:39 =#
    (ep === nothing || reserve <= 80) && return false
    #= none:40 =#
    total = 1 + min(8, ep[NID(0x0000000000000491)])
    #= none:40 =#
    share = total / length(ep[NID(0x0000000000000485)])
    #= none:41 =#
    for key = keys(ep[NID(0x0000000000000485)])
        #= none:42 =#
        e = (s[NID(0x0000000000000485)])[key]
        #= none:42 =#
        e[NID(0x000000000000048f)] += 1
        #= none:42 =#
        e[NID(0x000000000000048d)] = min(8.0, e[NID(0x000000000000048d)] + share)
        #= none:43 =#
    end
    #= none:44 =#
    ep[NID(0x0000000000000494)] = source
    #= none:44 =#
    ep[NID(0x0000000000000495)] = now
    #= none:44 =#
    ep[NID(0x000000000000020e)] = total
    #= none:45 =#
    push!(s[NID(0x0000000000000162)], ep)
    #= none:45 =#
    s[NID(0x000000000000048a)] = nothing
    #= none:45 =#
    true
end
