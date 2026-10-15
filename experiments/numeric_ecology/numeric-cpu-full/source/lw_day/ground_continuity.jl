# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
ground_points(v, g) = begin
        #= none:2 =#
        [(((v[NID(0x00000000000003aa)])[i + 1])[NID(0x0000000000000084)] * sind(((v[NID(0x00000000000003aa)])[i + 1])[NID(0x0000000000000348)]), ((v[NID(0x00000000000003aa)])[i + 1])[NID(0x0000000000000084)] * cosd(((v[NID(0x00000000000003aa)])[i + 1])[NID(0x0000000000000348)])) for i = g[NID(0x00000000000003e8)]]
    end
point_near(p, q, r) = begin
        #= none:3 =#
        hypot(p[1] - q[1], p[2] - q[2]) <= r
    end
function ground_memory(actor)
    #= none:4 =#
    #= none:5 =#
    D(NID(0x0000000000000259) => actor, NID(0x0000000000000407) => 0, NID(0x00000000000002e4) => Any[], NID(0x0000000000000121) => nothing, NID(0x00000000000002cc) => -1, NID(0x000000000000012f) => Any[], NID(0x0000000000000300) => 0, NID(0x0000000000000408) => 0)
end
function update_ground!(s, v, result, patterns = nothing)
    #= none:8 =#
    #= none:9 =#
    source = v[NID(0x0000000000000121)]
    #= none:9 =#
    source[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] || error(NID(0x0000000000000409))
    #= none:10 =#
    source[NID(0x00000000000003e4)] == s[NID(0x0000000000000121)] && return s
    #= none:11 =#
    linked = result !== nothing && (result[NID(0x0000000000000259)] == s[NID(0x0000000000000259)] && (result[NID(0x0000000000000121)] == s[NID(0x0000000000000121)] && (result[NID(0x0000000000000328)] == s[NID(0x00000000000002cc)] && result[NID(0x0000000000000329)] == source[NID(0x00000000000002cc)])))
    #= none:13 =#
    empty!(s[NID(0x000000000000012f)])
    #= none:14 =#
    if s[NID(0x0000000000000121)] !== nothing && !linked
        #= none:15 =#
        empty!(s[NID(0x00000000000002e4)])
        #= none:15 =#
        push!(s[NID(0x000000000000012f)], NID(0x000000000000040a))
    end
    #= none:17 =#
    if linked
        #= none:18 =#
        s[NID(0x0000000000000408)] += 1
        #= none:18 =#
        (sn, cs) = sincosd(result[NID(0x0000000000000095)])
        #= none:19 =#
        for m = s[NID(0x00000000000002e4)]
            #= none:20 =#
            push!(m[NID(0x000000000000040b)], copy(result))
            #= none:20 =#
            length(m[NID(0x000000000000040b)]) > 32 && popfirst!(m[NID(0x000000000000040b)])
            #= none:21 =#
            m[NID(0x00000000000003d2)] = [(cs * (x - result[NID(0x000000000000027a)]) - sn * (z - result[NID(0x0000000000000279)]), sn * (x - result[NID(0x000000000000027a)]) + cs * (z - result[NID(0x0000000000000279)])) for (x, z) = m[NID(0x00000000000003d2)]]
            #= none:22 =#
            m[NID(0x000000000000008a)] = NID(0x000000000000040c)
            #= none:22 =#
            m[NID(0x000000000000040d)] = Any[]
            #= none:23 =#
        end
    end
    #= none:25 =#
    filter!((m->begin
                #= none:25 =#
                source[NID(0x00000000000002cc)] - m[NID(0x000000000000040e)] <= 8000000
            end), s[NID(0x00000000000002e4)])
    #= none:26 =#
    patterns === nothing && (patterns = ground_patterns(v))
    #= none:27 =#
    groups = [g for g = patterns[NID(0x00000000000003cc)] if g[NID(0x0000000000000330)] in (NID(0x00000000000003e2), NID(0x00000000000003e1)) && g[NID(0x00000000000003ea)] == NID(0x00000000000003eb)]
    #= none:28 =#
    observed = [ground_points(v, g) for g = groups]
    #= none:29 =#
    choices = [[i for (i, m) = enumerate(s[NID(0x00000000000002e4)]) if count((p->begin
                            #= none:29 =#
                            any((q->begin
                                        #= none:29 =#
                                        point_near(p, q, 0.6)
                                    end), m[NID(0x00000000000003d2)])
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
            m = (s[NID(0x00000000000002e4)])[first(options)]
            #= none:35 =#
            m[NID(0x000000000000040f)] = any((p->begin
                            #= none:35 =#
                            all((q->begin
                                        #= none:35 =#
                                        !(point_near(p, q, 0.25))
                                    end), m[NID(0x00000000000003d2)])
                        end), ps)
            #= none:36 =#
            push!(m[NID(0x0000000000000410)], D(NID(0x0000000000000411) => last(m[NID(0x0000000000000412)]), NID(0x0000000000000413) => source[NID(0x00000000000003e4)], NID(0x0000000000000414) => copy(m[NID(0x000000000000040b)])))
            #= none:37 =#
            length(m[NID(0x0000000000000410)]) > 16 && popfirst!(m[NID(0x0000000000000410)])
            #= none:37 =#
            empty!(m[NID(0x000000000000040b)])
            #= none:38 =#
            m[NID(0x00000000000003d2)] = (vcat(ps, [q for q = m[NID(0x00000000000003d2)] if all((p->(#= none:38 =#
                                    !(point_near(p, q, 0.25)))), ps)]))[1:min(32, length(ps) + count((q->(#= none:38 =#
                                            all((p->(#= none:38 =#
                                                        !(point_near(p, q, 0.25)))), ps))), m[NID(0x00000000000003d2)]))]
        else
            #= none:40 =#
            if !(isempty(options))
                #= none:40 =#
                push!(s[NID(0x000000000000012f)], NID(0x0000000000000415))
                #= none:40 =#
                continue
            end
            #= none:41 =#
            if length(s[NID(0x00000000000002e4)]) >= 8
                #= none:41 =#
                push!(s[NID(0x000000000000012f)], NID(0x0000000000000416))
                #= none:41 =#
                continue
            end
            #= none:42 =#
            s[NID(0x0000000000000407)] += 1
            #= none:43 =#
            m = D(NID(0x000000000000008c) => ncat(NID(0x00000000000002e5), s[NID(0x0000000000000407)]), NID(0x00000000000003d2) => ps, NID(0x0000000000000412) => Any[], NID(0x0000000000000410) => Any[], NID(0x000000000000040b) => Any[], NID(0x000000000000040f) => false)
            #= none:44 =#
            push!(s[NID(0x00000000000002e4)], m)
        end
        #= none:46 =#
        push!(used, m[NID(0x000000000000008c)])
        #= none:46 =#
        m[NID(0x000000000000008a)] = NID(0x00000000000003fa)
        #= none:46 =#
        m[NID(0x000000000000040d)] = ps
        #= none:47 =#
        m[NID(0x000000000000040e)] = source[NID(0x00000000000002cc)]
        #= none:47 =#
        m[NID(0x00000000000003e6)] = g[NID(0x00000000000003e6)]
        #= none:48 =#
        push!(m[NID(0x0000000000000412)], source[NID(0x00000000000003e4)])
        #= none:48 =#
        length(m[NID(0x0000000000000412)]) > 16 && popfirst!(m[NID(0x0000000000000412)])
        #= none:49 =#
    end
    #= none:50 =#
    grass = [ground_points(v, g) for g = patterns[NID(0x00000000000003cc)] if g[NID(0x0000000000000330)] == NID(0x00000000000003e3)]
    #= none:51 =#
    for m = s[NID(0x00000000000002e4)]
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
                        end), m[NID(0x00000000000003d2)]) >= 2 && (m[NID(0x000000000000008a)] = NID(0x0000000000000417))
        #= none:54 =#
    end
    #= none:55 =#
    s[NID(0x0000000000000121)] = source[NID(0x00000000000003e4)]
    #= none:55 =#
    s[NID(0x00000000000002cc)] = source[NID(0x00000000000002cc)]
    #= none:55 =#
    s
end
function ground_proposals(s, move)
    #= none:57 =#
    #= none:58 =#
    out = Any[]
    #= none:59 =#
    for m = s[NID(0x00000000000002e4)]
        #= none:60 =#
        m[NID(0x000000000000008a)] == NID(0x00000000000003fa) || continue
        #= none:61 =#
        (x, z) = last(sort(m[NID(0x000000000000040d)], by = (q->begin
                                #= none:61 =#
                                (hypot(q...), q[2], q[1])
                            end)))
        #= none:62 =#
        angle = rad2deg(atan(x, z))
        #= none:63 =#
        safe = [i for i = 1:5 if (((move[NID(0x000000000000030b)])[NID(0x000000000000030c)])[i])[NID(0x000000000000030a)] !== nothing && abs(ANGLES[i] - angle) <= 22.5]
        #= none:64 =#
        isempty(safe) && continue
        #= none:65 =#
        i = first(sort(safe, by = (i->begin
                                #= none:65 =#
                                abs(ANGLES[i] - angle)
                            end)))
        #= none:66 =#
        push!(out, D(NID(0x00000000000001b7) => m[NID(0x000000000000008c)], NID(0x000000000000021f) => NID(0x000000000000030d), NID(0x0000000000000251) => i - 1, NID(0x00000000000002fc) => 2.25, NID(0x00000000000001b4) => NID(0x00000000000002da)))
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
                end), state[NID(0x00000000000002e4)])
    #= none:76 =#
    index === nothing && return nothing
    #= none:77 =#
    model = (state[NID(0x00000000000002e4)])[index]
    #= none:78 =#
    model[NID(0x000000000000008a)] == NID(0x00000000000003fa) || return nothing
    #= none:79 =#
    status == NID(0x0000000000000299) && (moved && model[NID(0x000000000000040f)])
end
