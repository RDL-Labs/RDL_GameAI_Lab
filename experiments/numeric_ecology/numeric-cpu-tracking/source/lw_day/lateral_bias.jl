# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function composed_lateral_bias(terrain, side)
    #= none:3 =#
    #= none:4 =#
    side in (NID(0x0000000000000282), NID(0x000000000000027c)) || error(NID(0x0000000000000017))
    #= none:5 =#
    out = deepcopy(terrain)
    #= none:5 =#
    samples = out[NID(0x0000000000000624)]
    #= none:6 =#
    rows = Dict((r[NID(0x0000000000000389)] => r for r = samples))
    #= none:6 =#
    eligible = Set{Int}()
    #= none:7 =#
    if out[NID(0x000000000000008a)] == NID(0x000000000000034f) && !(0 in out[NID(0x0000000000000625)])
        #= none:8 =#
        for angle = (45, 90)
            #= none:9 =#
            (left, right) = (rows[-angle], rows[angle])
            #= none:10 =#
            left[NID(0x000000000000008a)] == NID(0x0000000000000216) && right[NID(0x000000000000008a)] == NID(0x0000000000000216) || continue
            #= none:11 =#
            any((a->begin
                            #= none:11 =#
                            a in out[NID(0x0000000000000625)]
                        end), (-angle, angle)) || continue
            #= none:12 =#
            any((k->begin
                            #= none:12 =#
                            abs(get(left, k, 0) - get(right, k, 0)) > 0.1 + 1.0e-9
                        end), (NID(0x0000000000000147), NID(0x000000000000000d), NID(0x000000000000061f), NID(0x0000000000000626), NID(0x000000000000046e))) && continue
            #= none:14 =#
            union!(eligible, (-angle, angle))
            #= none:15 =#
        end
    end
    #= none:17 =#
    prior = deepcopy(out[NID(0x0000000000000625)])
    #= none:18 =#
    for row = samples
        #= none:19 =#
        angle = row[NID(0x0000000000000389)]
        #= none:20 =#
        cost = if angle in eligible
                if (angle < 0) == (side == NID(0x0000000000000282))
                    -0.05
                else
                    0.05
                end
            else
                0.0
            end
        #= none:21 =#
        row[NID(0x0000000000000627)] = if row[NID(0x000000000000008a)] == NID(0x0000000000000216)
                cost
            else
                nothing
            end
        #= none:22 =#
        row[NID(0x000000000000008a)] == NID(0x0000000000000216) && (row[NID(0x000000000000046e)] += cost)
        #= none:23 =#
    end
    #= none:24 =#
    if !(isempty(eligible))
        #= none:25 =#
        minimum_value = minimum((r[NID(0x000000000000046e)] for r = samples if r[NID(0x000000000000008a)] == NID(0x0000000000000216)))
        #= none:26 =#
        out[NID(0x0000000000000628)] = minimum_value
        #= none:27 =#
        out[NID(0x0000000000000625)] = [r[NID(0x0000000000000389)] for r = samples if r[NID(0x000000000000008a)] == NID(0x0000000000000216) && abs(r[NID(0x000000000000046e)] - minimum_value) <= 1.0e-9]
    end
    #= none:29 =#
    out[NID(0x000000000000033c)] = Dict(NID(0x00000000000000c6) => NID(0x0000000000000629), NID(0x000000000000061a) => side, NID(0x000000000000031a) => 0.05, NID(0x0000000000000600) => 0.1, NID(0x000000000000037d) => sort(collect(eligible)), NID(0x0000000000000289) => !(isempty(eligible)), NID(0x000000000000062a) => prior, NID(0x000000000000062b) => out[NID(0x0000000000000625)])
    #= none:32 =#
    out
end
function lateral_obstacles(objects, position, yaw, source)
    #= none:36 =#
    #= none:37 =#
    items = Any[]
    #= none:38 =#
    for (i, angle) = enumerate(-90:30:90)
        #= none:39 =#
        (sn, cs) = sincos(deg2rad(yaw + angle))
        #= none:39 =#
        best = Inf
        #= none:40 =#
        for o = objects
            #= none:41 =#
            o.height >= 1 || continue
            #= none:42 =#
            d = RDLMigrationProbe.ray_hit(position, (sn, cs), RDLMigrationProbe.Circle(o.x, o.z, o.radius))
            #= none:43 =#
            d !== nothing && (d <= 12 && (best = min(best, d)))
            #= none:44 =#
        end
        #= none:45 =#
        isfinite(best) && push!(items, Dict(NID(0x0000000000000195) => ncat(source, NID(0x000000000000062c), i - 1), NID(0x000000000000027b) => max(0.0, best * cosd(angle)), NID(0x000000000000027c) => best * sind(angle)))
        #= none:47 =#
    end
    #= none:48 =#
    Dict(NID(0x0000000000000121) => source, NID(0x000000000000034e) => NID(0x000000000000034f), NID(0x0000000000000386) => false, NID(0x00000000000005ca) => items)
end
function lateral_terrain(move, obstacles; model_cost = Dict{Int, Float64}())
    #= none:51 =#
    #= none:52 =#
    ground = (move[NID(0x0000000000000385)])[NID(0x0000000000000036)]
    #= none:53 =#
    complete = move[NID(0x0000000000000383)] == NID(0x000000000000034f) && (ground[NID(0x000000000000034e)] == NID(0x000000000000034f) && (!(ground[NID(0x0000000000000386)]) && (obstacles[NID(0x000000000000034e)] == NID(0x000000000000034f) && !(obstacles[NID(0x0000000000000386)]))))
    #= none:55 =#
    foods = [f for f = move[NID(0x00000000000001dd)] if f[NID(0x0000000000000332)] == NID(0x00000000000004cc)]
    #= none:56 =#
    rows = Any[]
    #= none:57 =#
    for surface = ground[NID(0x0000000000000359)]
        #= none:58 =#
        angle = surface[NID(0x0000000000000389)]
        #= none:58 =#
        (f, r) = (cosd(angle), sind(angle))
        #= none:59 =#
        physical = nothing
        #= none:59 =#
        food = nothing
        #= none:59 =#
        obstacle = nothing
        #= none:59 =#
        total = nothing
        #= none:59 =#
        status = NID(0x000000000000062d)
        #= none:60 =#
        mc = get(model_cost, angle, 0.0)
        #= none:61 =#
        if complete
            #= none:62 =#
            food = sum(sort([(-4 * max(0.0, 1 - hypot(f - x[NID(0x000000000000027b)], r - x[NID(0x000000000000027c)]) / 12)) / max(1, length(foods)) for x = foods]); init = 0.0)
            #= none:63 =#
            parts = Float64[]
            #= none:64 =#
            for x = obstacles[NID(0x00000000000005ca)]
                #= none:65 =#
                t = clamp(x[NID(0x000000000000027b)] * f + x[NID(0x000000000000027c)] * r, 0.0, 1.0)
                #= none:66 =#
                push!(parts, 6 * max(0.0, 1 - hypot(x[NID(0x000000000000027b)] - t * f, x[NID(0x000000000000027c)] - t * r) / 6) ^ 2)
                #= none:67 =#
            end
            #= none:68 =#
            obstacle = min(12.0, sum(sort(parts); init = 0.0))
            #= none:69 =#
            scored = surface[NID(0x000000000000008a)] == NID(0x0000000000000387) && abs(surface[NID(0x0000000000000388)]) <= 1
            #= none:70 =#
            status = if scored
                    NID(0x0000000000000216)
                else
                    NID(0x000000000000062e)
                end
            #= none:71 =#
            if scored
                #= none:72 =#
                physical = 2 * abs(surface[NID(0x0000000000000388)])
                #= none:72 =#
                total = physical + food + obstacle + mc
            end
        end
        #= none:75 =#
        push!(rows, Dict(NID(0x0000000000000389) => angle, NID(0x000000000000008a) => status, NID(0x0000000000000147) => physical, NID(0x000000000000000d) => food, NID(0x000000000000061f) => obstacle, NID(0x0000000000000626) => mc, NID(0x000000000000046e) => total))
        #= none:77 =#
    end
    #= none:78 =#
    scored = [x for x = rows if x[NID(0x000000000000008a)] == NID(0x0000000000000216)]
    #= none:79 =#
    low = if isempty(scored)
            nothing
        else
            minimum((x[NID(0x000000000000046e)] for x = scored))
        end
    #= none:80 =#
    Dict(NID(0x000000000000008a) => if !complete
                NID(0x000000000000062f)
            else
                if isempty(scored)
                    NID(0x0000000000000630)
                else
                    NID(0x000000000000034f)
                end
            end, NID(0x0000000000000624) => rows, NID(0x0000000000000628) => low, NID(0x0000000000000625) => if complete
                [x[NID(0x0000000000000389)] for x = scored if abs(x[NID(0x000000000000046e)] - low) <= 1.0e-9]
            else
                nothing
            end)
end
function project_lateral!(candidates, move, obstacles, side, field_trace)
    #= none:85 =#
    #= none:86 =#
    costs = Dict{Int, Float64}()
    #= none:87 =#
    if field_trace !== nothing && field_trace[NID(0x0000000000000289)]
        #= none:88 =#
        for c = candidates
            #= none:89 =#
            c[NID(0x000000000000021f)] == NID(0x000000000000030f) || continue
            #= none:90 =#
            terms = [x[NID(0x00000000000001b3)] for x = field_trace[NID(0x0000000000000631)] if x[NID(0x00000000000001b7)] == c[NID(0x00000000000001b7)]]
            #= none:91 =#
            isempty(terms) || (costs[ANGLES[c[NID(0x0000000000000251)] + 1]] = -(first(terms)))
            #= none:92 =#
        end
    end
    #= none:94 =#
    terrain = composed_lateral_bias(lateral_terrain(move, obstacles; model_cost = costs), side)
    #= none:95 =#
    for c = candidates
        #= none:96 =#
        c[NID(0x000000000000021f)] == NID(0x000000000000030f) || continue
        #= none:97 =#
        row = (terrain[NID(0x0000000000000624)])[c[NID(0x0000000000000251)] + 1]
        #= none:98 =#
        row[NID(0x0000000000000627)] === nothing || (c[NID(0x00000000000002fe)] -= row[NID(0x0000000000000627)])
        #= none:99 =#
    end
    #= none:100 =#
    terrain[NID(0x000000000000033c)]
end
