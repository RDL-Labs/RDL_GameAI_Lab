# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
cargo_ground() = begin
        #= none:1 =#
        D(NID(0x00000000000002ba) => Dict{Int, Any}(), NID(0x000000000000024a) => D(), NID(0x00000000000002bc) => Dict{Int, Int}(), NID(0x000000000000011f) => 0, NID(0x00000000000002e0) => 0, NID(0x000000000000033f) => 0, NID(0x000000000000028a) => Any[])
    end
function cargo_transfer!(g, w, cargo, food, stock, a, op, now, kind; index = 0)
    #= none:3 =#
    #= none:4 =#
    request = (kind = kind, index = index, position = w.positions[a])
    #= none:5 =#
    if haskey(g[NID(0x000000000000024a)], a)
        #= none:6 =#
        old = (g[NID(0x000000000000024a)])[a]
        #= none:7 =#
        if old.now == now
            #= none:8 =#
            check(old.op == op && old.request == request, NID(0x0000000000000425))
            #= none:8 =#
            return old.status
        end
        #= none:10 =#
        check(now > old.now, NID(0x0000000000000426))
    end
    #= none:12 =#
    status = NID(0x0000000000000327)
    #= none:13 =#
    if kind == NID(0x0000000000000325) && w.inventory[a] > 0
        #= none:14 =#
        reusable = findfirst((i->begin
                        #= none:14 =#
                        stock[i] == 0 && (get(g[NID(0x00000000000002bc)], i, now) >= 0 && get(g[NID(0x00000000000002bc)], i, now) < now)
                    end), sort(collect(keys(g[NID(0x00000000000002ba)]))))
        #= none:15 =#
        ids = sort(collect(keys(g[NID(0x00000000000002ba)])))
        #= none:16 =#
        j = if reusable === nothing
                length(food) + 1
            else
                ids[reusable]
            end
        #= none:17 =#
        if reusable !== nothing || length(ids) < 256
            #= none:18 =#
            p = w.positions[a]
            #= none:18 =#
            item = (x = p[1], z = p[2], stock = 0, appearance = NID(0x0000000000000427))
            #= none:19 =#
            if j > length(food)
                #= none:19 =#
                push!(food, item)
                #= none:19 =#
                push!(stock, 0)
            else
                #= none:19 =#
                food[j] = item
            end
            #= none:20 =#
            source = popfirst!(cargo[a])
            #= none:20 =#
            w.inventory[a] -= 1
            #= none:20 =#
            stock[j] = 1
            #= none:21 =#
            (g[NID(0x00000000000002ba)])[j] = (source = source, dropper = a, drop_operation = op)
            #= none:22 =#
            g[NID(0x000000000000011f)] += 1
            #= none:22 =#
            status = NID(0x000000000000011f)
        else
            #= none:24 =#
            status = NID(0x0000000000000428)
        end
    elseif #= none:26 =# kind == NID(0x00000000000002fb) && (haskey(g[NID(0x00000000000002ba)], index) && stock[index] > 0)
        #= none:27 =#
        f = food[index]
        #= none:27 =#
        p = w.positions[a]
        #= none:28 =#
        if hypot(f.x - p[1], f.z - p[2]) <= 1.25 && !(any((o->begin
                                #= none:28 =#
                                segment_hit(p, (Float64(f.x), Float64(f.z)), o, 0.0)
                            end), w.obstacles))
            #= none:29 =#
            origin = (g[NID(0x00000000000002ba)])[index]
            #= none:29 =#
            stock[index] -= 1
            #= none:29 =#
            w.inventory[a] += 1
            #= none:29 =#
            (g[NID(0x00000000000002bc)])[index] = now
            #= none:30 =#
            push!(cargo[a], origin.source)
            #= none:30 =#
            g[NID(0x00000000000002e0)] += 1
            #= none:31 =#
            origin.dropper != a && (g[NID(0x000000000000033f)] += 1)
            #= none:32 =#
            status = NID(0x00000000000002e0)
        end
    end
    #= none:35 =#
    (g[NID(0x000000000000024a)])[a] = (now = now, op = op, request = request, status = status)
    #= none:36 =#
    push!(g[NID(0x000000000000028a)], D(NID(0x0000000000000259) => a, NID(0x0000000000000328) => op, NID(0x000000000000024d) => kind, NID(0x000000000000008a) => status, NID(0x00000000000002d3) => now))
    #= none:37 =#
    length(g[NID(0x000000000000028a)]) > 32 && popfirst!(g[NID(0x000000000000028a)])
    #= none:38 =#
    status
end
function drop_candidates(samples, body, load, target)
    #= none:41 =#
    #= none:42 =#
    load > 0 && target !== nothing || return Any[]
    #= none:43 =#
    out = Any[]
    #= none:44 =#
    for row = samples
        #= none:45 =#
        capacity = (0.6 * (1 - body.damage)) / (1 + 0.1 * (load - 1))
        #= none:46 =#
        row[NID(0x000000000000031a)] > row[NID(0x00000000000000ac)] + 1.0e-12 && row[NID(0x000000000000031a)] <= capacity + 1.0e-12 || continue
        #= none:47 =#
        row[NID(0x0000000000000420)] && row[NID(0x000000000000041f)] || continue
        #= none:48 =#
        (step(body, NID(0x0000000000000317), load - 1, row[NID(0x0000000000000231)], true))[2] == NID(0x000000000000029b) || continue
        #= none:49 =#
        angle = deg2rad(Float64(ANGLES[row[NID(0x0000000000000251)] + 1]))
        #= none:50 =#
        alignment = cos(atan(target[NID(0x000000000000027c)], target[NID(0x000000000000027b)]) - angle)
        #= none:51 =#
        push!(out, D(NID(0x00000000000001b7) => ncat(NID(0x0000000000000429), ANGLES[row[NID(0x0000000000000251)] + 1]), NID(0x000000000000021f) => NID(0x0000000000000325), NID(0x00000000000002fe) => (3.0 + alignment) - 0.2, NID(0x00000000000001b4) => NID(0x00000000000002df)))
        #= none:53 =#
    end
    #= none:54 =#
    out
end
