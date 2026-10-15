# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function local_descent(target, obstacles)
    #= none:3 =#
    #= none:4 =#
    target === nothing && return nothing
    #= none:5 =#
    obstacles[NID(0x000000000000034e)] == NID(0x000000000000034f) && !(obstacles[NID(0x0000000000000386)]) || return nothing
    #= none:6 =#
    d = Float64(target[NID(0x0000000000000084)])
    #= none:6 =#
    d > 1.25 || return nothing
    #= none:7 =#
    f = Float64(target[NID(0x000000000000027b)]) / d
    #= none:7 =#
    r = Float64(target[NID(0x000000000000027c)]) / d
    #= none:8 =#
    (af, ar) = (f, r)
    #= none:9 =#
    for o = obstacles[NID(0x00000000000005ca)]
        #= none:10 =#
        q = hypot(o[NID(0x000000000000027b)], o[NID(0x000000000000027c)])
        #= none:11 =#
        0 < q < 3 || continue
        #= none:12 =#
        strength = 2 * (1 - q / 3) ^ 2
        #= none:13 =#
        f -= (strength * o[NID(0x000000000000027b)]) / q
        #= none:13 =#
        r -= (strength * o[NID(0x000000000000027c)]) / q
        #= none:14 =#
    end
    #= none:15 =#
    magnitude = hypot(f, r)
    #= none:16 =#
    magnitude > 1.0e-8 || return nothing
    #= none:17 =#
    (angle = rad2deg(atan(r, f)), span = min(0.5, d - 1.0), attraction = (af, ar), combined = (f, r))
end
function steer_local_descent!(plan, target, obstacles, w, a, yaw, resistance_at)
    #= none:19 =#
    #= none:20 =#
    plan[NID(0x000000000000021f)] == NID(0x000000000000030f) && startswith(get(plan, NID(0x00000000000001b7), NID(0x0000000000000334)), NID(0x00000000000005c2)) || return false
    #= none:21 =#
    v = local_descent(target, obstacles)
    #= none:21 =#
    v === nothing && return false
    #= none:22 =#
    p = w.positions[a]
    #= none:22 =#
    (s, c) = sincos(deg2rad(yaw[a] + v.angle))
    #= none:23 =#
    span = min(v.span, 0.5 * (1 - (w.bodies[a]).damage))
    #= none:23 =#
    q = (p[1] + s * span, p[2] + c * span)
    #= none:24 =#
    clear = !(any((o->begin
                        #= none:24 =#
                        segment_hit(p, q, o, 0.2)
                    end), w.obstacles))
    #= none:25 =#
    resistance = resistance_at(((p[1] + q[1]) / 2, (p[2] + q[2]) / 2))
    #= none:26 =#
    (_, status, _, _) = step(w.bodies[a], NID(0x000000000000030f), w.inventory[a], resistance, clear)
    #= none:27 =#
    status == NID(0x000000000000029b) || return false
    #= none:28 =#
    plan[NID(0x000000000000031d)] = v.angle
    #= none:28 =#
    plan[NID(0x000000000000031e)] = span
    #= none:29 =#
    plan[NID(0x00000000000005cb)] = v.combined
    #= none:30 =#
    true
end
