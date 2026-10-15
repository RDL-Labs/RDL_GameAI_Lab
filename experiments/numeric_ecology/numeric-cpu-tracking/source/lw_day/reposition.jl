# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
reposition_state(actor) = begin
        #= none:3 =#
        D(NID(0x0000000000000259) => actor, NID(0x00000000000001e6) => nothing, NID(0x00000000000000ce) => nothing, NID(0x0000000000000381) => 0.0, NID(0x0000000000000284) => 0, NID(0x0000000000000304) => 0, NID(0x000000000000028a) => Any[])
    end
function reposition_candidates!(s, actor, movement, now; linked = false, purpose = NID(0x000000000000000d), home_unresolved = false)
    #= none:4 =#
    #= none:5 =#
    check(s[NID(0x0000000000000259)] == actor, NID(0x0000000000000382))
    #= none:6 =#
    previous = s[NID(0x00000000000000ce)]
    #= none:7 =#
    previous !== nothing && (now <= previous && return Any[])
    #= none:8 =#
    if s[NID(0x00000000000001e6)] != purpose
        #= none:9 =#
        s[NID(0x0000000000000381)] = 0.0
        #= none:9 =#
        s[NID(0x00000000000001e6)] = purpose
    end
    #= none:11 =#
    dt = if previous === nothing
            0.0
        else
            (now - previous) / 1.0e6
        end
    #= none:12 =#
    s[NID(0x00000000000000ce)] = now
    #= none:12 =#
    s[NID(0x0000000000000381)] = max(0.0, s[NID(0x0000000000000381)] - 0.5dt)
    #= none:13 =#
    eligible = purpose == NID(0x000000000000000d) && movement[NID(0x0000000000000383)] == NID(0x0000000000000384) || purpose == NID(0x0000000000000096) && home_unresolved
    #= none:14 =#
    eligible && linked || return Any[]
    #= none:15 =#
    s[NID(0x0000000000000381)] = min(8.0, s[NID(0x0000000000000381)] + 1.0)
    #= none:16 =#
    ground = (movement[NID(0x0000000000000385)])[NID(0x0000000000000036)]
    #= none:17 =#
    ground[NID(0x0000000000000386)] && return Any[]
    #= none:18 =#
    s[NID(0x0000000000000381)] >= 2 || return Any[]
    #= none:19 =#
    allowed = [i for (i, v) = enumerate(ground[NID(0x0000000000000359)]) if v[NID(0x000000000000008a)] == NID(0x0000000000000387) && (v[NID(0x0000000000000388)] !== nothing && (abs(v[NID(0x0000000000000388)]) <= 0.5 && (((movement[NID(0x000000000000030d)])[NID(0x000000000000030e)])[i])[NID(0x000000000000030c)] !== nothing))]
    #= none:21 =#
    near = [i for i = allowed if abs(((ground[NID(0x0000000000000359)])[i])[NID(0x0000000000000389)]) <= 45]
    #= none:22 =#
    s[NID(0x0000000000000381)] < 4 && (!(isempty(near)) && (allowed = near))
    #= none:23 =#
    candidates = [D(NID(0x00000000000001b7) => ncat(NID(0x0000000000000303), ((ground[NID(0x0000000000000359)])[i])[NID(0x0000000000000389)]), NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => i - 1, NID(0x00000000000002fe) => 3.5, NID(0x00000000000001b4) => NID(0x00000000000002e5)) for i = allowed]
    #= none:25 =#
    if !(isempty(candidates))
        #= none:26 =#
        s[NID(0x0000000000000284)] += 1
        #= none:27 =#
        push!(s[NID(0x000000000000028a)], D(NID(0x0000000000000121) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), actor), NID(0x0000000000000381) => s[NID(0x0000000000000381)], NID(0x00000000000001e6) => purpose, NID(0x000000000000038a) => [c[NID(0x0000000000000251)] for c = candidates]))
        #= none:29 =#
        length(s[NID(0x000000000000028a)]) > 32 && popfirst!(s[NID(0x000000000000028a)])
    end
    #= none:31 =#
    candidates
end
function search_review_result!(state, family, method, found, performed)
    #= none:35 =#
    #= none:36 =#
    if get(state, NID(0x000000000000038b), nothing) != family
        #= none:37 =#
        state[NID(0x000000000000038c)] = 0
        #= none:37 =#
        state[NID(0x000000000000038b)] = family
    end
    #= none:39 =#
    if found || method == NID(0x000000000000038d) && performed
        #= none:40 =#
        state[NID(0x000000000000038c)] = 0
    elseif #= none:41 =# startswith(method, NID(0x0000000000000303)) && performed
        #= none:42 =#
        state[NID(0x000000000000038c)] = min(32, get(state, NID(0x000000000000038c), 0) + 1)
    end
end
function project_search_review!(state, candidates, loop, target, family)
    #= none:45 =#
    #= none:46 =#
    target === nothing && get(state, NID(0x000000000000038b), nothing) == family || return
    #= none:47 =#
    h = get(state, NID(0x000000000000038c), 0)
    #= none:48 =#
    h >= loop.threshold || return
    #= none:49 =#
    for c = candidates
        #= none:50 =#
        c[NID(0x00000000000001b7)] == NID(0x000000000000038d) || continue
        #= none:52 =#
        c[NID(0x00000000000002fe)] += min(4.0, h / loop.threshold)
        #= none:53 =#
    end
end
