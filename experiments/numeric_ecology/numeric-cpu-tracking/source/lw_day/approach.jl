# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
near_target(t) = begin
        #= none:2 =#
        t !== nothing && 1.25 < t[NID(0x0000000000000084)] <= 16.0
    end
function refine_approach!(plan, target, w, a, yaw, resistance_at)
    #= none:3 =#
    #= none:4 =#
    near_target(target) && plan[NID(0x000000000000021f)] == NID(0x000000000000030f) || return false
    #= none:5 =#
    angle = rad2deg(atan(target[NID(0x000000000000027c)], target[NID(0x000000000000027b)]))
    #= none:6 =#
    coarse = ANGLES[plan[NID(0x0000000000000251)] + 1]
    #= none:7 =#
    abs(angle - coarse) <= 22.5 + 1.0e-9 || return false
    #= none:8 =#
    span = min(0.5 * (1 - (w.bodies[a]).damage), max(0.0, target[NID(0x0000000000000084)] - 1.0))
    #= none:9 =#
    theta = deg2rad(yaw[a] + angle)
    #= none:9 =#
    (s, c) = sincos(theta)
    #= none:9 =#
    p = w.positions[a]
    #= none:10 =#
    q = (p[1] + s * span, p[2] + c * span)
    #= none:11 =#
    clear = !(any((o->begin
                        #= none:11 =#
                        segment_hit(p, q, o, 0.2)
                    end), w.obstacles))
    #= none:12 =#
    resistance = resistance_at(((p[1] + q[1]) / 2, (p[2] + q[2]) / 2))
    #= none:13 =#
    (_, status, _, _) = step(w.bodies[a], NID(0x000000000000030f), w.inventory[a], resistance, clear)
    #= none:14 =#
    status == NID(0x000000000000029b) || return false
    #= none:15 =#
    plan[NID(0x000000000000031d)] = angle
    #= none:15 =#
    plan[NID(0x000000000000031e)] = span
    #= none:16 =#
    true
end
