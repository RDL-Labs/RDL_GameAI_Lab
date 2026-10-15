# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function ground_appearance(w, a, yaw, g, now; dry = (p->begin
                    #= none:2 =#
                    true
                end))
    #= none:2 =#
    #= none:3 =#
    p = w.positions[a]
    #= none:3 =#
    cells = Any[]
    #= none:4 =#
    for angle = ANGLES, distance = (1, 2, 4)
        #= none:5 =#
        (sn, cs) = sincos(deg2rad(yaw[a] + angle))
        #= none:5 =#
        q = (p[1] + sn * distance, p[2] + cs * distance)
        #= none:6 =#
        blocked = any((o->begin
                        #= none:6 =#
                        segment_hit(p, q, o, 0.0)
                    end), w.obstacles)
        #= none:7 =#
        c = if blocked
                nothing
            else
                wear_cell!(g, (floor(Int, q[1]), floor(Int, q[2])))
            end
        #= none:8 =#
        wear = if c === nothing
                0.0
            else
                c[NID(0x000000000000010e)]
            end
        #= none:9 =#
        push!(cells, D(NID(0x000000000000034a) => angle, NID(0x0000000000000084) => distance, NID(0x000000000000008a) => if blocked
                        NID(0x00000000000003e2)
                    else
                        NID(0x0000000000000387)
                    end, NID(0x0000000000000332) => if blocked
                        nothing
                    else
                        if !(dry(q))
                            NID(0x00000000000002b5)
                        else
                            if wear >= 10
                                NID(0x00000000000003e3)
                            else
                                if wear > 0
                                    NID(0x00000000000003e4)
                                else
                                    NID(0x00000000000003e5)
                                end
                            end
                        end
                    end))
        #= none:11 =#
    end
    #= none:12 =#
    D(NID(0x0000000000000121) => D(NID(0x0000000000000259) => a, NID(0x00000000000003e6) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), NID(0x00000000000002ce) => now), NID(0x000000000000034e) => if any((c->begin
                            #= none:13 =#
                            c[NID(0x000000000000008a)] == NID(0x00000000000003e2)
                        end), cells)
                NID(0x0000000000000384)
            else
                NID(0x000000000000034f)
            end, NID(0x00000000000003ac) => cells)
end
function ground_neighbors(i)
    #= none:15 =#
    #= none:16 =#
    (a, d) = divrem(i - 1, 3)
    #= none:17 =#
    [aa * 3 + dd + 1 for (aa, dd) = ((a - 1, d), (a + 1, d), (a, d - 1), (a, d + 1)) if 0 <= aa < 5 && 0 <= dd < 3]
end
function ground_patterns(v)
    #= none:19 =#
    #= none:20 =#
    cells = v[NID(0x00000000000003ac)]
    #= none:20 =#
    length(cells) == 15 || error(NID(0x00000000000003e7))
    #= none:21 =#
    remaining = Set((i for i = 1:15 if (cells[i])[NID(0x000000000000008a)] == NID(0x0000000000000387)))
    #= none:21 =#
    groups = Any[]
    #= none:22 =#
    while !(isempty(remaining))
        #= none:23 =#
        firstid = minimum(remaining)
        #= none:23 =#
        appearance = (cells[firstid])[NID(0x0000000000000332)]
        #= none:24 =#
        component = Set([firstid])
        #= none:24 =#
        todo = [firstid]
        #= none:24 =#
        delete!(remaining, firstid)
        #= none:25 =#
        while !(isempty(todo))
            #= none:26 =#
            i = pop!(todo)
            #= none:27 =#
            for j = ground_neighbors(i)
                #= none:28 =#
                if j in remaining && (cells[j])[NID(0x0000000000000332)] == appearance
                    #= none:29 =#
                    delete!(remaining, j)
                    #= none:29 =#
                    push!(component, j)
                    #= none:29 =#
                    push!(todo, j)
                end
                #= none:31 =#
            end
            #= none:32 =#
        end
        #= none:33 =#
        ids = sort(collect(component))
        #= none:34 =#
        points = [((cells[i])[NID(0x0000000000000084)] * sind((cells[i])[NID(0x000000000000034a)]), (cells[i])[NID(0x0000000000000084)] * cosd((cells[i])[NID(0x000000000000034a)])) for i = ids]
        #= none:35 =#
        n = length(points)
        #= none:35 =#
        mx = sum((p[1] for p = points)) / n
        #= none:35 =#
        mz = sum((p[2] for p = points)) / n
        #= none:36 =#
        xx = sum(((p[1] - mx) ^ 2 for p = points)) / n
        #= none:36 =#
        zz = sum(((p[2] - mz) ^ 2 for p = points)) / n
        #= none:37 =#
        xz = sum(((p[1] - mx) * (p[2] - mz) for p = points)) / n
        #= none:38 =#
        disc = sqrt((xx - zz) ^ 2 + 4 * xz * xz)
        #= none:38 =#
        major = (xx + zz + disc) / 2
        #= none:38 =#
        minor = max(0.0, ((xx + zz) - disc) / 2)
        #= none:39 =#
        band = n >= 3 && (major > 0 && major >= 4minor)
        #= none:40 =#
        unknown = sort(unique([j - 1 for i = ids for j = ground_neighbors(i) if (cells[j])[NID(0x000000000000008a)] == NID(0x00000000000003e2)]))
        #= none:41 =#
        push!(groups, D(NID(0x00000000000003e8) => (v[NID(0x0000000000000121)])[NID(0x00000000000003e6)] * ncat(NID(0x00000000000003e9), firstid - 1), NID(0x0000000000000332) => appearance, NID(0x00000000000003ea) => ids .- 1, NID(0x00000000000003eb) => [[i - 1, j - 1] for i = ids for j = ground_neighbors(i) if j in component && i < j], NID(0x00000000000003ec) => if band
                        NID(0x00000000000003ed)
                    else
                        if n >= 3
                            NID(0x00000000000003ee)
                        else
                            NID(0x00000000000003ef)
                        end
                    end, NID(0x00000000000003f0) => [minimum(((cells[i])[NID(0x000000000000034a)] for i = ids)), maximum(((cells[i])[NID(0x000000000000034a)] for i = ids))], NID(0x00000000000003f1) => [minimum(((cells[i])[NID(0x0000000000000084)] for i = ids)), maximum(((cells[i])[NID(0x0000000000000084)] for i = ids))], NID(0x00000000000003f2) => unknown, NID(0x00000000000003f3) => any((i->begin
                                #= none:47 =#
                                div(i - 1, 3) in (0, 4) || mod(i - 1, 3) in (0, 2)
                            end), ids), NID(0x00000000000003f4) => NID(0x00000000000003f5)))
        #= none:49 =#
    end
    #= none:50 =#
    D(NID(0x0000000000000121) => copy(v[NID(0x0000000000000121)]), NID(0x000000000000034e) => v[NID(0x000000000000034e)], NID(0x000000000000008a) => if isempty(groups)
                NID(0x0000000000000327)
            else
                NID(0x00000000000003f6)
            end, NID(0x00000000000003ce) => groups, NID(0x00000000000003f7) => NID(0x00000000000003f8))
end
function record_ground_patterns!(s, v, patterns = ground_patterns(v))
    #= none:53 =#
    #= none:54 =#
    s[NID(0x00000000000002b2)] += 1
    #= none:55 =#
    for g = patterns[NID(0x00000000000003ce)]
        #= none:56 =#
        key = g[NID(0x0000000000000332)] * NID(0x00000000000000da) * g[NID(0x00000000000003ec)]
        #= none:57 =#
        (s[NID(0x0000000000000086)])[key] = get(s[NID(0x0000000000000086)], key, 0) + 1
        #= none:58 =#
    end
    #= none:59 =#
    push!(s[NID(0x000000000000028a)], D(NID(0x00000000000003e6) => v, NID(0x000000000000016f) => patterns))
    #= none:60 =#
    length(s[NID(0x000000000000028a)]) > 16 && popfirst!(s[NID(0x000000000000028a)])
end
