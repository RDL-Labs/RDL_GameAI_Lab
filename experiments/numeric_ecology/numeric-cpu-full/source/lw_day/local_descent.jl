# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function local_descent(target, obstacles)
    #= none:3 =#
    #= none:4 =#
    target === nothing && return nothing
    #= none:5 =#
    obstacles[NID(0x000000000000034c)] == NID(0x000000000000034d) && !(obstacles[NID(0x0000000000000384)]) || return nothing
    #= none:6 =#
    d = Float64(target[NID(0x0000000000000084)])
    #= none:6 =#
    d > 1.25 || return nothing
    #= none:7 =#
    f = Float64(target[NID(0x0000000000000279)]) / d
    #= none:7 =#
    r = Float64(target[NID(0x000000000000027a)]) / d
    #= none:8 =#
    (af, ar) = (f, r)
    #= none:9 =#
    for o = obstacles[NID(0x00000000000005c8)]
        #= none:10 =#
        q = hypot(o[NID(0x0000000000000279)], o[NID(0x000000000000027a)])
        #= none:11 =#
        0 < q < 3 || continue
        #= none:12 =#
        strength = 2 * (1 - q / 3) ^ 2
        #= none:13 =#
        f -= (strength * o[NID(0x0000000000000279)]) / q
        #= none:13 =#
        r -= (strength * o[NID(0x000000000000027a)]) / q
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
    plan[NID(0x000000000000021f)] == NID(0x000000000000030d) && startswith(get(plan, NID(0x00000000000001b7), NID(0x0000000000000332)), NID(0x00000000000005c0)) || return false
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
    (_, status, _, _) = step(w.bodies[a], NID(0x000000000000030d), w.inventory[a], resistance, clear)
    #= none:27 =#
    status == NID(0x0000000000000299) || return false
    #= none:28 =#
    plan[NID(0x000000000000031b)] = v.angle
    #= none:28 =#
    plan[NID(0x000000000000031c)] = span
    #= none:29 =#
    plan[NID(0x00000000000005c9)] = v.combined
    #= none:30 =#
    true
end
