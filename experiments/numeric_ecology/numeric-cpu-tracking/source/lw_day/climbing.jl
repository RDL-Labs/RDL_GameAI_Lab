# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function climb_sample(w, a, yaw, index, low, high, resistance_at)
    #= none:2 =#
    #= none:3 =#
    p = w.positions[a]
    #= none:3 =#
    b = w.bodies[a]
    #= none:3 =#
    theta = deg2rad(yaw + ANGLES[index + 1])
    #= none:4 =#
    distance = 1 - b.damage
    #= none:4 =#
    q = (p[1] + sin(theta) * distance, p[2] + cos(theta) * distance)
    #= none:5 =#
    circles = [RDLMigrationProbe.Circle(o.x, o.z, o.radius) for o = low]
    #= none:6 =#
    touched = [o.height for (o, c) = zip(low, circles) if segment_hit(p, q, c, 0.2)]
    #= none:7 =#
    height = if isempty(touched)
            0.0
        else
            maximum(touched)
        end
    #= none:8 =#
    capacity = (0.6 * (1 - b.damage)) / (1 + 0.1 * w.inventory[a])
    #= none:9 =#
    landing = !(any((c->begin
                        #= none:9 =#
                        segment_hit(q, q, c, 0.2)
                    end), w.obstacles))
    #= none:10 =#
    clear = height > 0 && (height <= capacity + 1.0e-12 && (landing && !(any((c->begin
                                    #= none:10 =#
                                    segment_hit(p, q, c, 0.2)
                                end), high))))
    #= none:11 =#
    resistance = resistance_at(((p[1] + q[1]) / 2, (p[2] + q[2]) / 2))
    #= none:12 =#
    (_, status, d, delta) = step(b, NID(0x0000000000000317), w.inventory[a], resistance, clear)
    #= none:13 =#
    D(NID(0x0000000000000251) => index, NID(0x000000000000021f) => NID(0x0000000000000317), NID(0x000000000000031a) => height, NID(0x00000000000000ac) => capacity, NID(0x000000000000041f) => !(any((c->begin
                            #= none:14 =#
                            segment_hit(p, q, c, 0.2)
                        end), high)), NID(0x0000000000000420) => landing, NID(0x000000000000022e) => clear, NID(0x0000000000000318) => w.inventory[a], NID(0x0000000000000231) => resistance, NID(0x000000000000008a) => status, NID(0x000000000000030c) => if status == NID(0x000000000000029b)
                -(delta[NID(0x000000000000014e)])
            else
                nothing
            end, NID(0x0000000000000084) => d, NID(0x0000000000000319) => delta)
end
function climb_candidates(samples, movement, target, loop)
    #= none:19 =#
    #= none:20 =#
    target === nothing && (loop.H < loop.threshold && return Any[])
    #= none:21 =#
    out = Any[]
    #= none:22 =#
    for row = samples
        #= none:23 =#
        row[NID(0x000000000000030c)] === nothing && continue
        #= none:24 =#
        i = row[NID(0x0000000000000251)]
        #= none:25 =#
        (((movement[NID(0x000000000000030d)])[NID(0x000000000000030e)])[i + 1])[NID(0x000000000000030c)] === nothing || continue
        #= none:26 =#
        angle = deg2rad(Float64(ANGLES[i + 1]))
        #= none:27 =#
        alignment = if target === nothing
                0.0
            else
                cos(atan(target[NID(0x000000000000027c)], target[NID(0x000000000000027b)]) - angle)
            end
        #= none:28 =#
        push!(out, D(NID(0x00000000000001b7) => ncat(NID(0x0000000000000421), ANGLES[i + 1]), NID(0x000000000000021f) => NID(0x0000000000000317), NID(0x0000000000000251) => i, NID(0x00000000000002fe) => if target === nothing
                            1.5
                        else
                            3.0 + alignment
                        end - 0.1 * row[NID(0x0000000000000231)] * (1 + 0.1 * row[NID(0x0000000000000318)]), NID(0x00000000000001b4) => if target === nothing
                        NID(0x00000000000002e5)
                    else
                        NID(0x0000000000000422)
                    end))
        #= none:31 =#
    end
    #= none:32 =#
    out
end
