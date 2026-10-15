# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
using SHA
wrap_angle(x) = begin
        #= none:3 =#
        mod(x + 180, 360) - 180
    end
function relation_scene(ob)
    #= none:4 =#
    #= none:5 =#
    ob[NID(0x000000000000034e)] == NID(0x000000000000034f) && !(get(ob, NID(0x0000000000000386), false)) || return nothing
    #= none:6 =#
    out = Any[]
    #= none:7 =#
    for color = sort(unique((f[NID(0x000000000000038e)] for f = ob[NID(0x0000000000000341)])))
        #= none:8 =#
        ps = landmark_patches(ob, color)
        #= none:8 =#
        length(ps) == 1 || continue
        #= none:9 =#
        bands = unique((f[NID(0x000000000000039f)] for f = ob[NID(0x0000000000000341)] if f[NID(0x000000000000038e)] == color))
        #= none:10 =#
        length(bands) == 1 || continue
        #= none:11 =#
        push!(out, D(NID(0x000000000000038e) => color, NID(0x000000000000034a) => (ps[1])[NID(0x000000000000034a)], NID(0x000000000000039f) => first(bands)))
        #= none:12 =#
        length(out) == 5 && break
        #= none:13 =#
    end
    #= none:14 =#
    out
end
function compare_relation(ob, target)
    #= none:16 =#
    #= none:17 =#
    current = relation_scene(ob)
    #= none:18 =#
    current === nothing && return D(NID(0x000000000000008a) => NID(0x0000000000000327), NID(0x00000000000000ec) => Any[])
    #= none:19 =#
    old = Dict((x[NID(0x000000000000038e)] => x for x = get(target, NID(0x0000000000000044), Any[])))
    #= none:19 =#
    now = Dict((x[NID(0x000000000000038e)] => x for x = current))
    #= none:20 =#
    common = sort(collect(intersect(keys(old), keys(now))))
    #= none:21 =#
    length(common) < 2 && return D(NID(0x000000000000008a) => NID(0x0000000000000616), NID(0x00000000000000ec) => Any[])
    #= none:22 =#
    pairs = Any[]
    #= none:23 =#
    for i = 1:length(common), j = i + 1:length(common)
        #= none:24 =#
        (a, b) = (common[i], common[j])
        #= none:25 =#
        expected = wrap_angle((old[b])[NID(0x000000000000034a)] - (old[a])[NID(0x000000000000034a)])
        #= none:25 =#
        actual = wrap_angle((now[b])[NID(0x000000000000034a)] - (now[a])[NID(0x000000000000034a)])
        #= none:26 =#
        push!(pairs, D(NID(0x0000000000000399) => [a, b], NID(0x0000000000000226) => expected, NID(0x0000000000000225) => actual, NID(0x000000000000036f) => wrap_angle(expected - actual)))
        #= none:27 =#
    end
    #= none:28 =#
    D(NID(0x000000000000008a) => NID(0x000000000000022a), NID(0x00000000000000ec) => pairs, NID(0x00000000000001c8) => current, NID(0x0000000000000617) => all((abs(p[NID(0x000000000000036f)]) <= 7.5 for p = pairs)))
end
function relation_cost(rel, angle, weight; goal_angle = nothing)
    #= none:30 =#
    #= none:31 =#
    cost = 0.0
    #= none:32 =#
    if rel[NID(0x000000000000008a)] == NID(0x000000000000022a)
        #= none:33 =#
        pred = Dict{NID, Float64}()
        #= none:34 =#
        for x = rel[NID(0x00000000000001c8)]
            #= none:35 =#
            d = if x[NID(0x000000000000039f)] == NID(0x000000000000023e)
                    4.0
                else
                    if x[NID(0x000000000000039f)] == NID(0x00000000000003a0)
                        12.0
                    else
                        24.0
                    end
                end
            #= none:36 =#
            pred[x[NID(0x000000000000038e)]] = atand(d * sind(x[NID(0x000000000000034a)]) - sind(angle), d * cosd(x[NID(0x000000000000034a)]) - cosd(angle))
            #= none:37 =#
        end
        #= none:38 =#
        for p = rel[NID(0x00000000000000ec)]
            #= none:39 =#
            (a, b) = p[NID(0x0000000000000399)]
            #= none:39 =#
            error = wrap_angle(p[NID(0x0000000000000226)] - wrap_angle(pred[b] - pred[a]))
            #= none:40 =#
            cost += clamp((error ^ 2 - p[NID(0x000000000000036f)] ^ 2) / 900, -1.0, 1.0)
            #= none:41 =#
        end
        #= none:42 =#
        cost *= weight / length(rel[NID(0x00000000000000ec)])
    end
    #= none:44 =#
    cost + if goal_angle === nothing
            0.0
        else
            -0.75 * cosd(wrap_angle(angle - goal_angle))
        end
end
function relation_signature(points)
    #= none:46 =#
    #= none:47 =#
    [[(a[NID(0x000000000000038e)], b[NID(0x000000000000038e)], round(Int, (b[NID(0x000000000000034a)] - a[NID(0x000000000000034a)]) / 15)) for (i, a) = enumerate(get(p, NID(0x0000000000000044), Any[])) for b = (get(p, NID(0x0000000000000044), Any[]))[i + 1:var"end"]] for p = points]
end
relation_field_state() = begin
        #= none:50 =#
        D(NID(0x0000000000000353) => nothing, NID(0x00000000000001b9) => nothing, NID(0x0000000000000288) => 0, NID(0x0000000000000606) => 0, NID(0x0000000000000302) => 0, NID(0x000000000000028a) => Any[])
    end
function relation_candidates!(state, move, ob, m, goal, source)
    #= none:51 =#
    #= none:52 =#
    eligible = Any[]
    #= none:53 =#
    for key = sort(collect(keys(m[NID(0x0000000000000132)])))
        #= none:54 =#
        n = (m[NID(0x0000000000000132)])[key]
        #= none:54 =#
        n[NID(0x00000000000001b9)] == goal || continue
        #= none:55 =#
        cursor = get(m[NID(0x00000000000002ff)], key, 1)
        #= none:56 =#
        while cursor <= length(n[NID(0x00000000000003d4)])
            #= none:57 =#
            rel = compare_relation(ob, (n[NID(0x00000000000003d4)])[cursor])
            #= none:58 =#
            get(rel, NID(0x0000000000000617), false) || break
            #= none:59 =#
            cursor += 1
            #= none:60 =#
        end
        #= none:61 =#
        (m[NID(0x00000000000002ff)])[key] = cursor
        #= none:62 =#
        cursor > length(n[NID(0x00000000000003d4)]) && continue
        #= none:63 =#
        rel = compare_relation(ob, (n[NID(0x00000000000003d4)])[cursor])
        #= none:63 =#
        rel[NID(0x000000000000008a)] == NID(0x000000000000022a) || continue
        #= none:64 =#
        push!(eligible, (key = key, score = (1 + 0.25 * n[NID(0x0000000000000605)]) / (1 + n[NID(0x00000000000001e8)]), relation = rel))
        #= none:65 =#
    end
    #= none:66 =#
    state[NID(0x0000000000000288)] += 1
    #= none:67 =#
    if isempty(eligible)
        #= none:67 =#
        state[NID(0x0000000000000353)] = nothing
        #= none:67 =#
        return Any[]
    end
    #= none:68 =#
    owner = if state[NID(0x00000000000001b9)] == goal
            state[NID(0x0000000000000353)]
        else
            nothing
        end
    #= none:69 =#
    index = findfirst((x->begin
                    #= none:69 =#
                    x.key == owner
                end), eligible)
    #= none:70 =#
    selected = if index === nothing
            first(sort(eligible, by = (x->begin
                                #= none:70 =#
                                (-(x.score), x.key)
                            end)))
        else
            eligible[index]
        end
    #= none:71 =#
    state[NID(0x0000000000000353)] = selected.key
    #= none:71 =#
    state[NID(0x00000000000001b9)] = goal
    #= none:72 =#
    weight = (min(1.0, selected.score / 3) * selected.score) / sum((x.score for x = eligible))
    #= none:73 =#
    out = Any[]
    #= none:73 =#
    samples = Any[]
    #= none:74 =#
    for r = (move[NID(0x000000000000030d)])[NID(0x000000000000030e)]
        #= none:75 =#
        r[NID(0x000000000000030c)] === nothing && continue
        #= none:76 =#
        i = parse(Int, r[NID(0x0000000000000195)])
        #= none:76 =#
        angle = ANGLES[i + 1]
        #= none:76 =#
        cost = relation_cost(selected.relation, angle, weight)
        #= none:77 =#
        push!(samples, D(NID(0x0000000000000251) => angle, NID(0x000000000000030c) => cost))
        #= none:78 =#
        push!(out, D(NID(0x00000000000001b7) => NID(0x0000000000000305) * selected.key * NID(0x00000000000000da) * ncat(angle), NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => i, NID(0x00000000000002fe) => 2.5 - cost, NID(0x00000000000001b4) => NID(0x00000000000002e1), NID(0x000000000000025b) => selected.key, NID(0x00000000000003a4) => source))
        #= none:80 =#
    end
    #= none:81 =#
    state[NID(0x0000000000000606)] += length(out)
    #= none:82 =#
    push!(state[NID(0x000000000000028a)], D(NID(0x0000000000000121) => source, NID(0x0000000000000353) => selected.key, NID(0x00000000000002ed) => weight, NID(0x0000000000000615) => selected.relation, NID(0x0000000000000359) => samples))
    #= none:83 =#
    length(state[NID(0x000000000000028a)]) > 32 && popfirst!(state[NID(0x000000000000028a)])
    #= none:84 =#
    out
end
