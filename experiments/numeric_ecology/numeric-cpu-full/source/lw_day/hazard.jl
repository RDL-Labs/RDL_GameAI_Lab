# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function hazard_observation(w, a, yaw, hazards, sec; visual_obstacles = w.obstacles)
    #= none:2 =#
    #= none:3 =#
    features = Any[]
    #= none:3 =#
    p = w.positions[a]
    #= none:3 =#
    (s, c) = sincos(deg2rad(yaw[a]))
    #= none:4 =#
    for h = hazards
        #= none:5 =#
        h.start <= sec < h.stop || continue
        #= none:6 =#
        q = (Float64(h.x + h.vx * (sec - h.start)), Float64(h.z + h.vz * (sec - h.start)))
        #= none:7 =#
        (dx, dz) = (q[1] - p[1], q[2] - p[2])
        #= none:7 =#
        (f, r) = (dx * s + dz * c, dx * c - dz * s)
        #= none:7 =#
        d = hypot(dx, dz)
        #= none:8 =#
        if d <= 12 && (f >= 0 && !(any((o->begin
                                    #= none:8 =#
                                    segment_hit(p, q, o, 0.0)
                                end), visual_obstacles)))
            #= none:9 =#
            push!(features, D(NID(0x0000000000000279) => f, NID(0x000000000000027a) => r, NID(0x0000000000000084) => d))
        end
        #= none:11 =#
    end
    #= none:12 =#
    D(NID(0x000000000000034c) => NID(0x000000000000034d), NID(0x000000000000033f) => features)
end
safety_state() = begin
        #= none:15 =#
        D(NID(0x00000000000001bc) => false, NID(0x00000000000001e8) => 0, NID(0x000000000000013e) => 8, NID(0x000000000000034e) => 0, NID(0x000000000000034f) => 0, NID(0x0000000000000350) => 0)
    end
function safety_plan!(s, ob, movement; running = false)
    #= none:16 =#
    #= none:17 =#
    features = ob[NID(0x000000000000033f)]
    #= none:18 =#
    if !(isempty(features))
        #= none:19 =#
        !(s[NID(0x00000000000001bc)]) && (s[NID(0x000000000000034e)] += 1)
        #= none:20 =#
        s[NID(0x00000000000001bc)] = true
        #= none:20 =#
        s[NID(0x00000000000001e8)] = 0
    elseif #= none:21 =# s[NID(0x00000000000001bc)]
        #= none:22 =#
        s[NID(0x00000000000001e8)] = min(s[NID(0x000000000000013e)], s[NID(0x00000000000001e8)] + if ob[NID(0x000000000000034c)] == NID(0x000000000000034d)
                        2
                    else
                        1
                    end)
        #= none:23 =#
        if s[NID(0x00000000000001e8)] >= s[NID(0x000000000000013e)]
            #= none:24 =#
            s[NID(0x00000000000001bc)] = false
            #= none:24 =#
            s[NID(0x000000000000034f)] += 1
            #= none:25 =#
            return nothing
        end
    end
    #= none:28 =#
    s[NID(0x00000000000001bc)] || return nothing
    #= none:29 =#
    s[NID(0x0000000000000350)] += 1
    #= none:30 =#
    if !(isempty(features))
        #= none:31 =#
        h = features[argmin([f[NID(0x0000000000000084)] for f = features])]
        #= none:32 =#
        rows = [r for r = (movement[NID(0x000000000000030b)])[NID(0x000000000000030c)] if r[NID(0x000000000000030a)] !== nothing]
        #= none:34 =#
        away(r) = begin
                #= none:34 =#
                #= none:35 =#
                angle = deg2rad(ANGLES[parse(Int, r[NID(0x0000000000000195)]) + 1])
                #= none:36 =#
                -((h[NID(0x0000000000000279)] * cos(angle) + h[NID(0x000000000000027a)] * sin(angle)))
            end
        #= none:38 =#
        running && append!(rows, [r for r = movement[NID(0x000000000000031d)] if r[NID(0x000000000000030a)] !== nothing])
        #= none:39 =#
        rows = filter((r->begin
                        #= none:39 =#
                        away(r) > 0
                    end), rows)
        #= none:40 =#
        if !(isempty(rows))
            #= none:41 =#
            score(r) = begin
                    #= none:41 =#
                    if running
                        (away(r) / max(h[NID(0x0000000000000084)], 0.001)) * if get(r, NID(0x000000000000021f), NID(0x000000000000030d)) == NID(0x000000000000031a)
                                    r[NID(0x0000000000000084)]
                                else
                                    0.5
                                end - 0.05 * r[NID(0x0000000000000231)] * (1 + 0.1 * r[NID(0x0000000000000316)]) * if get(r, NID(0x000000000000021f), NID(0x000000000000030d)) == NID(0x000000000000031a)
                                    5
                                else
                                    1
                                end
                    else
                        away(r)
                    end
                end
            #= none:42 =#
            r = rows[argmax(score.(rows))]
            #= none:43 =#
            return D(NID(0x000000000000021f) => get(r, NID(0x000000000000021f), NID(0x000000000000030d)), NID(0x0000000000000251) => parse(Int, r[NID(0x0000000000000195)]), NID(0x000000000000007b) => true)
        end
    end
    #= none:46 =#
    D(NID(0x000000000000021f) => NID(0x0000000000000309), NID(0x000000000000007b) => true)
end
