# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
using SHA
function experienced_response(obs, records, pressure, owner, seed; retention = 0.0)
    #= none:3 =#
    #= none:4 =#
    check(obs[NID(0x000000000000043f)] == owner && pressure.parent.goal_id == owner * NID(0x0000000000000440), NID(0x0000000000000441))
    #= none:5 =#
    m = first(obs[NID(0x00000000000001c3)])
    #= none:5 =#
    other = m[NID(0x0000000000000442)]
    #= none:6 =#
    if m[NID(0x000000000000024d)] != NID(0x00000000000002e8) || !(any((x->begin
                            #= none:6 =#
                            x[NID(0x0000000000000195)] == other
                        end), obs[NID(0x00000000000002f4)]))
        #= none:7 =#
        return (response(obs, true), nothing)
    end
    #= none:9 =#
    sources = NID[]
    #= none:9 =#
    weight = 0.0
    #= none:10 =#
    for (id, r) = records
        #= none:11 =#
        check(r[NID(0x00000000000002cd)] == owner, NID(0x0000000000000443))
        #= none:12 =#
        r[NID(0x00000000000001b0)] == other && r[NID(0x0000000000000336)] == NID(0x00000000000002ac) || continue
        #= none:13 =#
        evidence = (pressure.methods[other]).records[id]
        #= none:14 =#
        check(evidence[NID(0x0000000000000444)] == 1 && (evidence[NID(0x0000000000000431)])[NID(0x0000000000000121)] == r[NID(0x0000000000000445)], NID(0x0000000000000446))
        #= none:15 =#
        push!(sources, id)
        #= none:15 =#
        weight = max(weight, min(2.0, 0.6 * evidence[NID(0x0000000000000447)]))
        #= none:16 =#
    end
    #= none:17 =#
    reserve = (obs[NID(0x0000000000000080)])[NID(0x000000000000014e)]
    #= none:17 =#
    need = max(0.0, (80 - reserve) / 40)
    #= none:18 =#
    score = ((1.0 - need) - weight) - retention
    #= none:19 =#
    probability = if obs[NID(0x0000000000000081)] > 0
            exp(score) / (1 + exp(score))
        else
            0.0
        end
    #= none:20 =#
    digest = sha256(seed)
    #= none:20 =#
    bits = foldl(((x, b)->begin
                    #= none:20 =#
                    x << 8 | UInt64(b)
                end), digest[1:8]; init = UInt64(0))
    #= none:21 =#
    draw = Float64(bits) / 1.8446744073709552e19
    #= none:22 =#
    action = if draw < 1 - probability
            NID(0x00000000000002ac)
        else
            NID(0x00000000000002ab)
        end
    #= none:23 =#
    trace = D(NID(0x0000000000000121) => seed, NID(0x0000000000000430) => other, NID(0x00000000000002ed) => weight, NID(0x0000000000000414) => sources, NID(0x0000000000000432) => need, NID(0x00000000000001cd) => retention, NID(0x0000000000000448) => probability, NID(0x000000000000043d) => draw, NID(0x0000000000000304) => action, NID(0x00000000000003f7) => NID(0x0000000000000449))
    #= none:26 =#
    ((action, other, m[NID(0x0000000000000237)]), trace)
end
function experienced_request(obs, records, pressure, owner, other, seed)
    #= none:32 =#
    #= none:33 =#
    check(obs[NID(0x000000000000043f)] == owner && pressure.parent.goal_id == owner * NID(0x0000000000000440), NID(0x000000000000044a))
    #= none:34 =#
    contact = findfirst((x->begin
                    #= none:34 =#
                    x[NID(0x0000000000000195)] == other
                end), obs[NID(0x00000000000002f4)])
    #= none:35 =#
    check(contact !== nothing, NID(0x000000000000044b))
    #= none:36 =#
    sources = NID[]
    #= none:36 =#
    weight = 0.0
    #= none:37 =#
    for (id, r) = records
        #= none:38 =#
        check(r[NID(0x00000000000002cd)] == owner, NID(0x000000000000044c))
        #= none:39 =#
        r[NID(0x00000000000001b0)] == other && r[NID(0x0000000000000336)] == NID(0x00000000000002ac) || continue
        #= none:40 =#
        evidence = (pressure.methods[other]).records[id]
        #= none:41 =#
        check(evidence[NID(0x0000000000000444)] == 1 && (evidence[NID(0x0000000000000431)])[NID(0x0000000000000121)] == r[NID(0x0000000000000445)], NID(0x000000000000044d))
        #= none:42 =#
        push!(sources, id)
        #= none:42 =#
        weight = max(weight, min(2.0, 0.6 * evidence[NID(0x0000000000000447)]))
        #= none:43 =#
    end
    #= none:44 =#
    probability = if ((obs[NID(0x00000000000002f4)])[contact])[NID(0x00000000000002f3)]
            exp(1 - weight) / (1 + exp(1 - weight))
        else
            0.0
        end
    #= none:45 =#
    bits = foldl(((x, b)->begin
                    #= none:45 =#
                    x << 8 | UInt64(b)
                end), (sha256(seed))[1:8]; init = UInt64(0))
    #= none:46 =#
    draw = Float64(bits) / 1.8446744073709552e19
    #= none:47 =#
    selected = draw >= 1 - probability
    #= none:48 =#
    (selected, D(NID(0x0000000000000121) => seed, NID(0x0000000000000430) => other, NID(0x00000000000001b4) => NID(0x000000000000044e), NID(0x00000000000002ed) => weight, NID(0x0000000000000414) => sources, NID(0x000000000000044f) => probability, NID(0x000000000000043d) => draw, NID(0x0000000000000304) => if selected
                    NID(0x00000000000002e8)
                else
                    NID(0x0000000000000450)
                end))
end
