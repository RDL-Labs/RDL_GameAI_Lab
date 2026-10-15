# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
mutable struct GroundWear
    #= none:3 =#
    cells::Dict{Tuple{Int, Int}, Any}
    #= none:4 =#
    receipts::Dict{NID, Any}
    #= none:5 =#
    now::Int
    #= none:6 =#
    day::Int
    #= none:7 =#
    recovery::Bool
    #= none:8 =#
    operations::Int
end
GroundWear(day; recovery = true) = begin
        #= none:10 =#
        GroundWear(Dict{Tuple{Int, Int}, Any}(), Dict{NID, Any}(), 0, day, recovery, 0)
    end
function advance_wear!(g, now)
    #= none:11 =#
    #= none:12 =#
    now >= g.now || error(NID(0x00000000000003bb))
    #= none:14 =#
    now > g.now && empty!(g.receipts)
    #= none:15 =#
    g.now = now
end
function wear_cell!(g, key)
    #= none:17 =#
    #= none:18 =#
    c = get(g.cells, key, nothing)
    #= none:19 =#
    c === nothing && return nothing
    #= none:20 =#
    if g.recovery
        #= none:21 =#
        elapsed = max(0, (g.now - c[NID(0x00000000000003ba)]) - g.day)
        #= none:22 =#
        c[NID(0x000000000000010e)] = max(0.0, c[NID(0x00000000000003bc)] - (2 * elapsed) / g.day)
    end
    #= none:24 =#
    c
end
function wear_factor(g, p)
    #= none:26 =#
    #= none:27 =#
    c = wear_cell!(g, (floor(Int, p[1]), floor(Int, p[2])))
    #= none:28 =#
    if c === nothing
        1.0
    else
        1 - 0.5 * min(1.0, c[NID(0x000000000000010e)] / 10)
    end
end
function tread!(g, op, agent, start, finish, now; walkable = (p->begin
                    #= none:30 =#
                    true
                end))
    #= none:30 =#
    #= none:31 =#
    now == g.now || error(NID(0x00000000000003bd))
    #= none:32 =#
    source = (op, start, finish)
    #= none:33 =#
    if haskey(g.receipts, agent)
        #= none:34 =#
        g.receipts[agent] == source || error(NID(0x00000000000003be))
        #= none:35 =#
        return
    end
    #= none:37 =#
    d = hypot(finish[1] - start[1], finish[2] - start[2])
    #= none:38 =#
    d == 0 && return
    #= none:39 =#
    g.receipts[agent] = source
    #= none:39 =#
    g.operations += 1
    #= none:40 =#
    n = max(1, ceil(Int, d / 0.1))
    #= none:41 =#
    for i = 0:n - 1
        #= none:42 =#
        t = (i + 0.5) / n
        #= none:43 =#
        point = (start[1] + t * (finish[1] - start[1]), start[2] + t * (finish[2] - start[2]))
        #= none:44 =#
        walkable(point) || continue
        #= none:45 =#
        key = (floor(Int, point[1]), floor(Int, point[2]))
        #= none:46 =#
        c = wear_cell!(g, key)
        #= none:47 =#
        if c === nothing
            #= none:48 =#
            c = D(NID(0x0000000000000084) => 0.0, NID(0x000000000000010e) => 0.0, NID(0x00000000000003ba) => now, NID(0x00000000000003bc) => 0.0, NID(0x000000000000007c) => D())
            #= none:49 =#
            g.cells[key] = c
        end
        #= none:51 =#
        c[NID(0x0000000000000084)] += d / n
        #= none:51 =#
        c[NID(0x000000000000010e)] += d / n
        #= none:51 =#
        c[NID(0x00000000000003bc)] = c[NID(0x000000000000010e)]
        #= none:51 =#
        c[NID(0x00000000000003ba)] = now
        #= none:52 =#
        (c[NID(0x000000000000007c)])[agent] = get(c[NID(0x000000000000007c)], agent, 0.0) + d / n
        #= none:53 =#
    end
end
function wear_snapshot(g)
    #= none:55 =#
    #= none:56 =#
    cells = D()
    #= none:57 =#
    for key = sort(collect(keys(g.cells)))
        #= none:58 =#
        c = deepcopy(wear_cell!(g, key))
        #= none:58 =#
        delete!(c, NID(0x00000000000003bc))
        #= none:59 =#
        cells[ncat(key[1], NID(0x00000000000003bf), key[2])] = c
        #= none:60 =#
    end
    #= none:61 =#
    D(NID(0x00000000000000c6) => NID(0x00000000000003c0), NID(0x00000000000000cd) => g.now, NID(0x00000000000003b7) => g.recovery, NID(0x00000000000003b4) => g.day, NID(0x00000000000003b6) => 2, NID(0x00000000000003b5) => 1.0, NID(0x00000000000003c1) => 10.0, NID(0x0000000000000085) => g.operations, NID(0x00000000000003aa) => cells)
end
function restore_wear(snapshot, day)
    #= none:67 =#
    #= none:68 =#
    snapshot.rule == NID(0x00000000000003c0) && (snapshot.grace_us == day && (snapshot.cell_size == 1 && snapshot.recovery_per_day == 2)) || error(NID(0x00000000000003c2))
    #= none:69 =#
    snapshot.now_us >= 0 || error(NID(0x00000000000003c3))
    #= none:70 =#
    g = GroundWear(day; recovery = Bool(snapshot.recovery_enabled))
    #= none:70 =#
    g.now = Int(snapshot.now_us)
    #= none:70 =#
    g.operations = Int(snapshot.operations)
    #= none:71 =#
    for (key, v) = pairs(snapshot.cells)
        #= none:72 =#
        coords = parse.(Int, split(NID(key), ','))
        #= none:72 =#
        length(coords) == 2 || error(NID(0x00000000000003c4))
        #= none:73 =#
        isfinite(v.wear) && (isfinite(v.distance) && (0 <= v.wear <= v.distance + 1.0e-8 && 0 <= v.last_walk_us <= g.now)) || error(NID(0x00000000000003c5))
        #= none:76 =#
        elapsed = if g.recovery
                max(0, (g.now - Int(v.last_walk_us)) - day)
            else
                0
            end
        #= none:77 =#
        agents = D((if occursin('/', NID(a))
                        NID(a)
                    else
                        NID(0x00000000000002b9) * NID(a)
                    end => Float64(d) for (a, d) = pairs(v.agents)))
        #= none:78 =#
        all((isfinite(d) && d >= 0 for d = values(agents))) || error(NID(0x00000000000003c6))
        #= none:79 =#
        g.cells[(coords[1], coords[2])] = D(NID(0x0000000000000084) => Float64(v.distance), NID(0x000000000000010e) => Float64(v.wear), NID(0x00000000000003bc) => Float64(v.wear) + (2 * elapsed) / day, NID(0x00000000000003ba) => Int(v.last_walk_us), NID(0x000000000000007c) => agents)
        #= none:80 =#
    end
    #= none:81 =#
    g
end
