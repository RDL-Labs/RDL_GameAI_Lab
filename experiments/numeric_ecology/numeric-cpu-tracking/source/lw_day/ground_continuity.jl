# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
ground_points(v, g) = begin
        #= none:2 =#
        [(((v[NID(0x00000000000003ac)])[i + 1])[NID(0x0000000000000084)] * sind(((v[NID(0x00000000000003ac)])[i + 1])[NID(0x000000000000034a)]), ((v[NID(0x00000000000003ac)])[i + 1])[NID(0x0000000000000084)] * cosd(((v[NID(0x00000000000003ac)])[i + 1])[NID(0x000000000000034a)])) for i = g[NID(0x00000000000003ea)]]
    end
point_near(p, q, r) = begin
        #= none:3 =#
        hypot(p[1] - q[1], p[2] - q[2]) <= r
    end
function ground_memory(actor)
    #= none:4 =#
    #= none:5 =#
    D(NID(0x0000000000000259) => actor, NID(0x0000000000000409) => 0, NID(0x00000000000002e6) => Any[], NID(0x0000000000000121) => nothing, NID(0x00000000000002ce) => -1, NID(0x000000000000012f) => Any[], NID(0x0000000000000302) => 0, NID(0x000000000000040a) => 0)
end
function update_ground!(s, v, result, patterns = nothing)
    #= none:8 =#
    #= none:9 =#
    source = v[NID(0x0000000000000121)]
    #= none:9 =#
    source[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] || error(NID(0x000000000000040b))
    #= none:10 =#
    source[NID(0x00000000000003e6)] == s[NID(0x0000000000000121)] && return s
    #= none:11 =#
    linked = result !== nothing && (result[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] && (result[NID(0x0000000000000121)] == s[NID(0x0000000000000121)] && (result[NID(0x000000000000032a)] == s[NID(0x00000000000002ce)] && result[NID(0x000000000000032b)] == source[NID(0x00000000000002ce)])))
    #= none:13 =#
    empty!(s[NID(0x000000000000012f)])
    #= none:14 =#
    if s[NID(0x0000000000000121)] !== nothing && !linked
        #= none:15 =#
        empty!(s[NID(0x00000000000002e6)])
        #= none:15 =#
        push!(s[NID(0x000000000000012f)], NID(0x000000000000040c))
    end
    #= none:17 =#
    if linked
        #= none:18 =#
        s[NID(0x000000000000040a)] += 1
        #= none:18 =#
        (sn, cs) = sincosd(result[NID(0x0000000000000095)])
        #= none:19 =#
        for m = s[NID(0x00000000000002e6)]
            #= none:20 =#
            push!(m[NID(0x000000000000040d)], copy(result))
            #= none:20 =#
            length(m[NID(0x000000000000040d)]) > 32 && popfirst!(m[NID(0x000000000000040d)])
            #= none:21 =#
            m[NID(0x00000000000003d4)] = [(cs * (x - result[NID(0x000000000000027c)]) - sn * (z - result[NID(0x000000000000027b)]), sn * (x - result[NID(0x000000000000027c)]) + cs * (z - result[NID(0x000000000000027b)])) for (x, z) = m[NID(0x00000000000003d4)]]
            #= none:22 =#
            m[NID(0x000000000000008a)] = NID(0x000000000000040e)
            #= none:22 =#
            m[NID(0x000000000000040f)] = Any[]
            #= none:23 =#
        end
    end
    #= none:25 =#
    filter!((m->begin
                #= none:25 =#
                source[NID(0x00000000000002ce)] - m[NID(0x0000000000000410)] <= 8000000
            end), s[NID(0x00000000000002e6)])
    #= none:26 =#
    patterns === nothing && (patterns = ground_patterns(v))
    #= none:27 =#
    groups = [g for g = patterns[NID(0x00000000000003ce)] if g[NID(0x0000000000000332)] in (NID(0x00000000000003e4), NID(0x00000000000003e3)) && g[NID(0x00000000000003ec)] == NID(0x00000000000003ed)]
    #= none:28 =#
    observed = [ground_points(v, g) for g = groups]
    #= none:29 =#
    choices = [[i for (i, m) = enumerate(s[NID(0x00000000000002e6)]) if count((p->begin
                            #= none:29 =#
                            any((q->begin
                                        #= none:29 =#
                                        point_near(p, q, 0.6)
                                    end), m[NID(0x00000000000003d4)])
                        end), ps) >= 2] for ps = observed]
    #= none:30 =#
    used = Set{NID}()
    #= none:31 =#
    for (g, ps, options) = zip(groups, observed, choices)
        #= none:32 =#
        unique_match = length(options) == 1 && count((cs->begin
                                #= none:32 =#
                                first(options) in cs
                            end), choices) == 1
        #= none:33 =#
        if unique_match
            #= none:34 =#
            m = (s[NID(0x00000000000002e6)])[first(options)]
            #= none:35 =#
            m[NID(0x0000000000000411)] = any((p->begin
                            #= none:35 =#
                            all((q->begin
                                        #= none:35 =#
                                        !(point_near(p, q, 0.25))
                                    end), m[NID(0x00000000000003d4)])
                        end), ps)
            #= none:36 =#
            push!(m[NID(0x0000000000000412)], D(NID(0x0000000000000413) => last(m[NID(0x0000000000000414)]), NID(0x0000000000000415) => source[NID(0x00000000000003e6)], NID(0x0000000000000416) => copy(m[NID(0x000000000000040d)])))
            #= none:37 =#
            length(m[NID(0x0000000000000412)]) > 16 && popfirst!(m[NID(0x0000000000000412)])
            #= none:37 =#
            empty!(m[NID(0x000000000000040d)])
            #= none:38 =#
            m[NID(0x00000000000003d4)] = (vcat(ps, [q for q = m[NID(0x00000000000003d4)] if all((p->(#= none:38 =#
                                    !(point_near(p, q, 0.25)))), ps)]))[1:min(32, length(ps) + count((q->(#= none:38 =#
                                            all((p->(#= none:38 =#
                                                        !(point_near(p, q, 0.25)))), ps))), m[NID(0x00000000000003d4)]))]
        else
            #= none:40 =#
            if !(isempty(options))
                #= none:40 =#
                push!(s[NID(0x000000000000012f)], NID(0x0000000000000417))
                #= none:40 =#
                continue
            end
            #= none:41 =#
            if length(s[NID(0x00000000000002e6)]) >= 8
                #= none:41 =#
                push!(s[NID(0x000000000000012f)], NID(0x0000000000000418))
                #= none:41 =#
                continue
            end
            #= none:42 =#
            s[NID(0x0000000000000409)] += 1
            #= none:43 =#
            m = D(NID(0x000000000000008c) => ncat(NID(0x00000000000002e7), s[NID(0x0000000000000409)]), NID(0x00000000000003d4) => ps, NID(0x0000000000000414) => Any[], NID(0x0000000000000412) => Any[], NID(0x000000000000040d) => Any[], NID(0x0000000000000411) => false)
            #= none:44 =#
            push!(s[NID(0x00000000000002e6)], m)
        end
        #= none:46 =#
        push!(used, m[NID(0x000000000000008c)])
        #= none:46 =#
        m[NID(0x000000000000008a)] = NID(0x00000000000003fc)
        #= none:46 =#
        m[NID(0x000000000000040f)] = ps
        #= none:47 =#
        m[NID(0x0000000000000410)] = source[NID(0x00000000000002ce)]
        #= none:47 =#
        m[NID(0x00000000000003e8)] = g[NID(0x00000000000003e8)]
        #= none:48 =#
        push!(m[NID(0x0000000000000414)], source[NID(0x00000000000003e6)])
        #= none:48 =#
        length(m[NID(0x0000000000000414)]) > 16 && popfirst!(m[NID(0x0000000000000414)])
        #= none:49 =#
    end
    #= none:50 =#
    grass = [ground_points(v, g) for g = patterns[NID(0x00000000000003ce)] if g[NID(0x0000000000000332)] == NID(0x00000000000003e5)]
    #= none:51 =#
    for m = s[NID(0x00000000000002e6)]
        #= none:52 =#
        m[NID(0x000000000000008c)] in used && continue
        #= none:53 =#
        count((p->begin
                            #= none:53 =#
                            any((ps->begin
                                        #= none:53 =#
                                        any((q->begin
                                                    #= none:53 =#
                                                    point_near(p, q, 0.6)
                                                end), ps)
                                    end), grass)
                        end), m[NID(0x00000000000003d4)]) >= 2 && (m[NID(0x000000000000008a)] = NID(0x0000000000000419))
        #= none:54 =#
    end
    #= none:55 =#
    s[NID(0x0000000000000121)] = source[NID(0x00000000000003e6)]
    #= none:55 =#
    s[NID(0x00000000000002ce)] = source[NID(0x00000000000002ce)]
    #= none:55 =#
    s
end
function ground_proposals(s, move)
    #= none:57 =#
    #= none:58 =#
    out = Any[]
    #= none:59 =#
    for m = s[NID(0x00000000000002e6)]
        #= none:60 =#
        m[NID(0x000000000000008a)] == NID(0x00000000000003fc) || continue
        #= none:61 =#
        (x, z) = last(sort(m[NID(0x000000000000040f)], by = (q->begin
                                #= none:61 =#
                                (hypot(q...), q[2], q[1])
                            end)))
        #= none:62 =#
        angle = rad2deg(atan(x, z))
        #= none:63 =#
        safe = [i for i = 1:5 if (((move[NID(0x000000000000030d)])[NID(0x000000000000030e)])[i])[NID(0x000000000000030c)] !== nothing && abs(ANGLES[i] - angle) <= 22.5]
        #= none:64 =#
        isempty(safe) && continue
        #= none:65 =#
        i = first(sort(safe, by = (i->begin
                                #= none:65 =#
                                abs(ANGLES[i] - angle)
                            end)))
        #= none:66 =#
        push!(out, D(NID(0x00000000000001b7) => m[NID(0x000000000000008c)], NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => i - 1, NID(0x00000000000002fe) => 2.25, NID(0x00000000000001b4) => NID(0x00000000000002dc)))
        #= none:67 =#
    end
    #= none:68 =#
    out
end
function ground_extension_result(state, method, status, moved)
    #= none:73 =#
    #= none:74 =#
    state === nothing && return nothing
    #= none:75 =#
    index = findfirst((m->begin
                    #= none:75 =#
                    m[NID(0x000000000000008c)] == method
                end), state[NID(0x00000000000002e6)])
    #= none:76 =#
    index === nothing && return nothing
    #= none:77 =#
    model = (state[NID(0x00000000000002e6)])[index]
    #= none:78 =#
    model[NID(0x000000000000008a)] == NID(0x00000000000003fc) || return nothing
    #= none:79 =#
    status == NID(0x000000000000029b) && (moved && model[NID(0x0000000000000411)])
end
