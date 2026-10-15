# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
inertia_state(actor) = begin
        #= none:2 =#
        D(NID(0x0000000000000259) => actor, NID(0x00000000000001e8) => 0, NID(0x000000000000013e) => 4, NID(0x000000000000016d) => nothing, NID(0x00000000000000ce) => -1, NID(0x00000000000001ea) => nothing, NID(0x00000000000005df) => 0, NID(0x00000000000005e0) => D(), NID(0x000000000000028a) => Any[])
    end
function inertia_view(move, landmarks, hazard)
    #= none:4 =#
    #= none:5 =#
    Any[move[NID(0x0000000000000383)], [(r[NID(0x000000000000022e)], r[NID(0x000000000000008a)]) for r = (move[NID(0x000000000000030d)])[NID(0x000000000000030e)]], sort([(f[NID(0x000000000000038e)], Tuple(f[NID(0x000000000000039e)]), f[NID(0x000000000000039f)]) for f = landmarks[NID(0x0000000000000341)]]), sort([(f[NID(0x0000000000000332)], round(f[NID(0x0000000000000084)]; digits = 1)) for f = move[NID(0x00000000000001dd)]]), hazard[NID(0x000000000000034e)], hazard[NID(0x0000000000000341)]]
end
function observe_inertia!(s, actor, now, view)
    #= none:10 =#
    #= none:11 =#
    check(s[NID(0x0000000000000259)] == actor && now > s[NID(0x00000000000000ce)], NID(0x00000000000005e1))
    #= none:12 =#
    s[NID(0x00000000000001e8)] = if s[NID(0x000000000000016d)] !== nothing && s[NID(0x000000000000016d)] == view
            min(32, s[NID(0x00000000000001e8)] + 1)
        else
            0
        end
    #= none:13 =#
    s[NID(0x000000000000016d)] = view
    #= none:13 =#
    s[NID(0x00000000000000ce)] = now
end
function inertia_candidate!(s, move, hazard, phase, family, methods, source)
    #= none:15 =#
    #= none:16 =#
    r = s[NID(0x00000000000001ea)]
    #= none:17 =#
    reason = if r === nothing || (r.actor != s[NID(0x0000000000000259)] || r.executed_us != s[NID(0x00000000000000ce)])
            NID(0x00000000000005e2)
        else
            if !(phase in (NID(0x00000000000002d4), NID(0x00000000000002d5)))
                NID(0x00000000000005e3)
            else
                if r.phase != phase || r.family != family
                    NID(0x00000000000005e4)
                else
                    if hazard[NID(0x000000000000034e)] != NID(0x000000000000034f) || !(isempty(hazard[NID(0x0000000000000341)]))
                        NID(0x00000000000005e5)
                    else
                        if !(isempty(move[NID(0x00000000000001dd)]))
                            NID(0x00000000000005e6)
                        else
                            if (((move[NID(0x000000000000030d)])[NID(0x000000000000030e)])[3])[NID(0x000000000000030c)] === nothing
                                NID(0x00000000000005e7)
                            else
                                if s[NID(0x00000000000001e8)] >= s[NID(0x000000000000013e)]
                                    NID(0x00000000000005e8)
                                else
                                    if r.action != NID(0x000000000000030f) || (r.status != NID(0x000000000000029b) || (!(r.moved) || r.method === nothing))
                                        NID(0x00000000000005e9)
                                    else
                                        if startswith(r.method, NID(0x0000000000000303))
                                            NID(0x00000000000005ea)
                                        else
                                            if !(haskey(methods, r.method))
                                                NID(0x00000000000005eb)
                                            else
                                                nothing
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    #= none:27 =#
    if reason !== nothing
        #= none:28 =#
        (s[NID(0x00000000000005e0)])[reason] = get(s[NID(0x00000000000005e0)], reason, 0) + 1
        #= none:29 =#
        return nothing
    end
    #= none:31 =#
    s[NID(0x00000000000005df)] += 1
    #= none:32 =#
    push!(s[NID(0x000000000000028a)], D(NID(0x0000000000000121) => source, NID(0x0000000000000130) => r.source, NID(0x00000000000001b7) => r.method, NID(0x00000000000001e8) => s[NID(0x00000000000001e8)]))
    #= none:33 =#
    length(s[NID(0x000000000000028a)]) > 32 && popfirst!(s[NID(0x000000000000028a)])
    #= none:34 =#
    D(NID(0x00000000000001b7) => r.method, NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => 2, NID(0x00000000000002fe) => 10.0, NID(0x00000000000001b4) => NID(0x00000000000002dd), NID(0x000000000000025b) => r.route, NID(0x00000000000005ec) => true)
end
