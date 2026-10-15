# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
bundle_state(actor) = begin
        #= none:2 =#
        D(NID(0x0000000000000259) => actor, NID(0x00000000000001bc) => Any[], NID(0x0000000000000469) => Any[], NID(0x00000000000000c1) => Any[], NID(0x00000000000003fd) => Set{NID}(), NID(0x000000000000046d) => 0, NID(0x0000000000000407) => 0, NID(0x000000000000046e) => D(), NID(0x000000000000046f) => Int[], NID(0x000000000000032e) => Any[], NID(0x0000000000000470) => 0, NID(0x00000000000002fe) => 0, NID(0x0000000000000471) => 0)
    end
bundle_context(inventory, body, move, hazard) = begin
        #= none:3 =#
        Any[food_band(inventory), move[NID(0x0000000000000381)], !(isempty(move[NID(0x00000000000001dd)])), hazard[NID(0x000000000000034c)], !(isempty(hazard[NID(0x000000000000033f)])), body.reserve <= 80, body.strain >= 0.8]
    end
function remember_bundle!(s, record)
    #= none:4 =#
    #= none:5 =#
    record[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] || error(NID(0x0000000000000472))
    #= none:6 =#
    push!(s[NID(0x00000000000000c1)], deepcopy(record))
    #= none:6 =#
    length(s[NID(0x00000000000000c1)]) > 8 && popfirst!(s[NID(0x00000000000000c1)])
end
function form_bundle!(s, h, now)
    #= none:8 =#
    #= none:9 =#
    h[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] || error(NID(0x0000000000000473))
    #= none:10 =#
    h[NID(0x000000000000045a)] == s[NID(0x000000000000046d)] && return
    #= none:11 =#
    s[NID(0x000000000000046d)] = h[NID(0x000000000000045a)]
    #= none:12 =#
    h[NID(0x00000000000001e8)] >= h[NID(0x000000000000013e)] || return
    #= none:13 =#
    if length(s[NID(0x00000000000001bc)]) >= 32 || length(s[NID(0x00000000000001bc)]) + length(s[NID(0x0000000000000469)]) >= 256
        #= none:14 =#
        s[NID(0x0000000000000474)] = NID(0x0000000000000475)
        #= none:14 =#
        return
    end
    #= none:16 =#
    sources = [deepcopy(r) for r = s[NID(0x00000000000000c1)] if !(r[NID(0x0000000000000326)] in s[NID(0x00000000000003fd)]) && (0 < now - r[NID(0x00000000000002cc)] <= 10000000 && (r[NID(0x000000000000025a)] < now && !(r[NID(0x0000000000000334)] in (NID(0x0000000000000476), NID(0x0000000000000477)))))]
    #= none:17 =#
    isempty(sources) && return
    #= none:18 =#
    s[NID(0x0000000000000407)] += 1
    #= none:18 =#
    ref = ncat(NID(0x0000000000000478), s[NID(0x0000000000000259)], NID(0x00000000000000da), s[NID(0x0000000000000407)])
    #= none:19 =#
    push!(s[NID(0x00000000000001bc)], D(NID(0x000000000000008c) => ref, NID(0x0000000000000479) => now, NID(0x00000000000001e8) => h[NID(0x00000000000001e8)], NID(0x000000000000046d) => h[NID(0x000000000000045a)], NID(0x0000000000000412) => sources))
    #= none:20 =#
    union!(s[NID(0x00000000000003fd)], (r[NID(0x0000000000000326)] for r = sources))
    #= none:20 =#
    (s[NID(0x000000000000046e)])[ref] = D(NID(0x000000000000047a) => 0, NID(0x000000000000047b) => 0, NID(0x0000000000000371) => 0)
    #= none:21 =#
    s[NID(0x0000000000000474)] = NID(0x000000000000047c)
end
function wake_bundles!(s, context, phase)
    #= none:23 =#
    #= none:24 =#
    phase in (NID(0x00000000000002d2), NID(0x00000000000002d3)) || return
    #= none:25 =#
    keep = Any[]
    #= none:26 =#
    for b = s[NID(0x0000000000000469)]
        #= none:27 =#
        if length(s[NID(0x00000000000001bc)]) < 32 && any((r->begin
                            #= none:27 =#
                            r[NID(0x0000000000000250)] == context && r[NID(0x0000000000000116)] == phase
                        end), b[NID(0x0000000000000412)])
            #= none:28 =#
            push!(s[NID(0x00000000000001bc)], b)
            #= none:28 =#
            ((s[NID(0x000000000000046e)])[b[NID(0x000000000000008c)]])[NID(0x0000000000000371)] = 0
            #= none:28 =#
            s[NID(0x0000000000000470)] += 1
        else
            #= none:30 =#
            push!(keep, b)
        end
        #= none:32 =#
    end
    #= none:33 =#
    s[NID(0x0000000000000469)] = keep
end
function project_bundles!(s, candidates, loop, context, phase, now; credit = false)
    #= none:35 =#
    #= none:36 =#
    phase in (NID(0x00000000000002d2), NID(0x00000000000002d3)) || return nothing
    #= none:37 =#
    matches = [(b[NID(0x000000000000008c)], r) for b = s[NID(0x00000000000001bc)] for r = b[NID(0x0000000000000412)] if b[NID(0x0000000000000479)] < now && (r[NID(0x0000000000000250)] == context && r[NID(0x0000000000000116)] == phase)]
    #= none:38 =#
    isempty(matches) && return nothing
    #= none:39 =#
    baseline = (method_choice(loop, candidates))[NID(0x00000000000001b7)]
    #= none:39 =#
    refs = Set{NID}()
    #= none:39 =#
    contributors = Set{NID}()
    #= none:40 =#
    for (ref, _) = matches
        #= none:40 =#
        push!(refs, ref)
        #= none:40 =#
    end
    #= none:41 =#
    for c = candidates
        #= none:42 =#
        get(c, NID(0x000000000000045f), true) || continue
        #= none:43 =#
        evidence = [ref for (ref, r) = matches if r[NID(0x000000000000021f)] == c[NID(0x000000000000021f)]]
        #= none:44 =#
        isempty(evidence) && continue
        #= none:45 =#
        strength = if credit
                (get!(s, NID(0x000000000000047d), bundle_credit_state()))[NID(0x0000000000000465)]
            else
                D()
            end
        #= none:46 =#
        c[NID(0x00000000000002fc)] -= (0.75 * sum((1 + min(8.0, get(strength, ref, 0.0)) * 0.125 for ref = evidence))) / length(matches)
        #= none:46 =#
        union!(contributors, evidence)
        #= none:47 =#
    end
    #= none:48 =#
    selected = (method_choice(loop, candidates))[NID(0x00000000000001b7)]
    #= none:48 =#
    s[NID(0x0000000000000471)] += 1
    #= none:49 =#
    D(NID(0x0000000000000256) => baseline != selected, NID(0x0000000000000302) => selected, NID(0x0000000000000262) => sort(collect(refs)), NID(0x0000000000000335) => sort(collect(contributors)))
end
function use_bundles!(s, trace, method, status)
    #= none:51 =#
    #= none:52 =#
    trace === nothing && return
    #= none:53 =#
    used = trace[NID(0x0000000000000256)] && (method == trace[NID(0x0000000000000302)] && !(status in (NID(0x0000000000000476), NID(0x0000000000000477), NID(0x0000000000000308))))
    #= none:54 =#
    used && (s[NID(0x00000000000002fe)] += 1)
    #= none:55 =#
    for ref = trace[NID(0x0000000000000262)]
        #= none:56 =#
        ((s[NID(0x000000000000046e)])[ref])[NID(0x000000000000047b)] += 1
        #= none:57 =#
        used && (ref in trace[NID(0x0000000000000335)] && (((s[NID(0x000000000000046e)])[ref])[NID(0x000000000000047a)] += 1))
        #= none:58 =#
    end
end
function sleep_bundles!(s, day, formation)
    #= none:60 =#
    #= none:61 =#
    day in s[NID(0x000000000000046f)] && return
    #= none:62 =#
    active = Any[]
    #= none:62 =#
    decisions = Any[]
    #= none:63 =#
    for b = s[NID(0x00000000000001bc)]
        #= none:64 =#
        u = (s[NID(0x000000000000046e)])[b[NID(0x000000000000008c)]]
        #= none:65 =#
        if b[NID(0x0000000000000479)] >= formation
            #= none:65 =#
            push!(active, b)
            #= none:65 =#
            continue
        end
        #= none:66 =#
        u[NID(0x0000000000000371)] = if u[NID(0x000000000000047a)] > 0
                0
            else
                u[NID(0x0000000000000371)] + 1
            end
        #= none:67 =#
        dormant = u[NID(0x000000000000047a)] == 0 && u[NID(0x0000000000000371)] >= if u[NID(0x000000000000047b)] > 0
                        2
                    else
                        3
                    end
        #= none:68 =#
        push!(decisions, D(NID(0x000000000000008c) => b[NID(0x000000000000008c)], NID(0x000000000000047a) => u[NID(0x000000000000047a)], NID(0x000000000000047b) => u[NID(0x000000000000047b)], NID(0x0000000000000371) => u[NID(0x0000000000000371)], NID(0x0000000000000469) => dormant))
        #= none:69 =#
        push!(if dormant
                s[NID(0x0000000000000469)]
            else
                active
            end, b)
        #= none:69 =#
        u[NID(0x000000000000047a)] = 0
        #= none:69 =#
        u[NID(0x000000000000047b)] = 0
        #= none:70 =#
    end
    #= none:71 =#
    s[NID(0x00000000000001bc)] = active
    #= none:71 =#
    push!(s[NID(0x000000000000046f)], day)
    #= none:71 =#
    push!(s[NID(0x000000000000032e)], D(NID(0x0000000000000173) => day, NID(0x0000000000000281) => decisions))
end
bundle_snapshot(s) = begin
        #= none:73 =#
        D((k => if k == NID(0x00000000000003fd)
                    sort(collect(v))
                else
                    deepcopy(v)
                end for (k, v) = s))
    end
bundle_credit_state() = begin
        #= none:76 =#
        D(NID(0x0000000000000465) => D(), NID(0x0000000000000145) => D(), NID(0x0000000000000288) => D())
    end
function admit_bundle_credit!(s, trace, method, status, parent, op)
    #= none:77 =#
    #= none:78 =#
    trace === nothing && return
    #= none:79 =#
    trace[NID(0x0000000000000256)] && (method == trace[NID(0x0000000000000302)] && !(status in (NID(0x0000000000000476), NID(0x0000000000000477), NID(0x0000000000000308)))) || return
    #= none:80 =#
    parent[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] || error(NID(0x000000000000047e))
    #= none:81 =#
    parent[NID(0x0000000000000312)] === nothing && return
    #= none:82 =#
    c = get!(s, NID(0x000000000000047d), bundle_credit_state())
    #= none:82 =#
    trial = ncat(parent[NID(0x0000000000000312)])
    #= none:83 =#
    if haskey(c[NID(0x0000000000000145)], trial) || haskey(c[NID(0x0000000000000288)], trial)
        return
    else
        nothing
    end
    #= none:84 =#
    refs = trace[NID(0x0000000000000335)]
    #= none:84 =#
    isempty(refs) && return
    #= none:85 =#
    known = Set((b[NID(0x000000000000008c)] for b = vcat(s[NID(0x00000000000001bc)], s[NID(0x0000000000000469)])))
    #= none:86 =#
    all((ref in known for ref = refs)) || error(NID(0x000000000000047f))
    #= none:87 =#
    (c[NID(0x0000000000000145)])[trial] = D(NID(0x00000000000001e8) => parent[NID(0x00000000000001e8)], NID(0x0000000000000262) => copy(refs), NID(0x0000000000000326) => op)
end
function resolve_bundle_credit!(s, h)
    #= none:89 =#
    #= none:90 =#
    h[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] || error(NID(0x000000000000047e))
    #= none:91 =#
    c = get!(s, NID(0x000000000000047d), bundle_credit_state())
    #= none:92 =#
    for r = h[NID(0x0000000000000288)]
        #= none:93 =#
        trial = ncat(r[NID(0x000000000000045c)])
        #= none:93 =#
        haskey(c[NID(0x0000000000000145)], trial) || continue
        #= none:94 =#
        use = pop!(c[NID(0x0000000000000145)], trial)
        #= none:94 =#
        total = if r[NID(0x0000000000000442)] == 0
                min(8.0, use[NID(0x00000000000001e8)])
            else
                0.0
            end
        #= none:95 =#
        for ref = use[NID(0x0000000000000262)]
            #= none:96 =#
            (c[NID(0x0000000000000465)])[ref] = min(8.0, get(c[NID(0x0000000000000465)], ref, 0.0) + total / length(use[NID(0x0000000000000262)]))
            #= none:97 =#
        end
        #= none:98 =#
        (c[NID(0x0000000000000288)])[trial] = D(NID(0x000000000000046b) => use, NID(0x000000000000046d) => deepcopy(r), NID(0x000000000000020e) => total, NID(0x000000000000008a) => if total > 0
                        NID(0x0000000000000480)
                    else
                        NID(0x0000000000000481)
                    end)
        #= none:99 =#
    end
end
