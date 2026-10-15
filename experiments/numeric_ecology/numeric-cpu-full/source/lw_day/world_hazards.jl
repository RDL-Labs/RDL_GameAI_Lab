# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
function dynamic_hazards()
    #= none:2 =#
    #= none:3 =#
    D(NID(0x00000000000000ce) => nothing, NID(0x000000000000029b) => D(NID(0x000000000000007f) => (-20.0, -14.0), NID(0x0000000000000096) => (-20.0, -14.0), NID(0x00000000000000ef) => (-20.0, -2.0), NID(0x000000000000029c) => NID(0x0000000000000371), NID(0x00000000000001b0) => nothing), NID(0x000000000000017b) => D(NID(0x000000000000007f) => (-12.0, -8.0), NID(0x0000000000000356) => 0), NID(0x0000000000000086) => D(), NID(0x0000000000000288) => Any[])
end
function territory_step!(t, positions, dt, objects)
    #= none:6 =#
    #= none:7 =#
    home = t[NID(0x0000000000000096)]
    #= none:7 =#
    p = t[NID(0x000000000000007f)]
    #= none:7 =#
    center = t[NID(0x00000000000000ef)]
    #= none:8 =#
    inside = Dict((a => q for (a, q) = positions if hypot(q[1] - center[1], q[2] - center[2]) <= 8))
    #= none:9 =#
    target = t[NID(0x00000000000001b0)]
    #= none:9 =#
    mode = t[NID(0x000000000000029c)]
    #= none:10 =#
    if mode == NID(0x00000000000001da) || target !== nothing && !(haskey(inside, target))
        #= none:11 =#
        mode = NID(0x00000000000001da)
        #= none:11 =#
        target = nothing
        #= none:11 =#
        goal = home
    else
        #= none:13 =#
        if target === nothing && !(isempty(inside))
            #= none:14 =#
            target = first(sort(collect(keys(inside)), by = (a->begin
                                    #= none:14 =#
                                    (hypot((inside[a])[1] - p[1], (inside[a])[2] - p[2]), a)
                                end)))
        end
        #= none:16 =#
        if target === nothing
            #= none:17 =#
            mode = NID(0x0000000000000371)
            #= none:17 =#
            goal = home
        elseif #= none:18 =# hypot(p[1] - home[1], p[2] - home[2]) >= 12
            #= none:19 =#
            mode = NID(0x00000000000001da)
            #= none:19 =#
            target = nothing
            #= none:19 =#
            goal = home
        else
            #= none:21 =#
            goal = inside[target]
            #= none:21 =#
            mode = if hypot(goal[1] - p[1], goal[2] - p[2]) <= 3
                    NID(0x0000000000000372)
                else
                    NID(0x0000000000000373)
                end
        end
    end
    #= none:24 =#
    blocked = false
    #= none:25 =#
    if mode in (NID(0x0000000000000373), NID(0x00000000000001da))
        #= none:26 =#
        (dx, dz) = (goal[1] - p[1], goal[2] - p[2])
        #= none:26 =#
        distance = hypot(dx, dz)
        #= none:27 =#
        travel = min(2dt, max(0.0, distance - if mode == NID(0x0000000000000373)
                            3
                        else
                            0
                        end))
        #= none:28 =#
        q = if distance == 0
                p
            else
                (p[1] + (dx * travel) / distance, p[2] + (dz * travel) / distance)
            end
        #= none:29 =#
        if mode == NID(0x0000000000000373) && hypot(q[1] - home[1], q[2] - home[2]) > 12
            #= none:30 =#
            mode = NID(0x00000000000001da)
            #= none:30 =#
            target = nothing
        elseif #= none:31 =# travel > 0 && any((o->begin
                            #= none:31 =#
                            segment_hit(p, q, o, 0.5)
                        end), objects)
            #= none:32 =#
            blocked = true
        else
            #= none:34 =#
            t[NID(0x000000000000007f)] = q
        end
        #= none:36 =#
        mode == NID(0x00000000000001da) && (hypot((t[NID(0x000000000000007f)])[1] - home[1], (t[NID(0x000000000000007f)])[2] - home[2]) < 1.0e-8 && (mode = NID(0x0000000000000371)))
    end
    #= none:38 =#
    t[NID(0x000000000000029c)] = mode
    #= none:38 =#
    t[NID(0x00000000000001b0)] = target
    #= none:38 =#
    blocked
end
function advance_hazards!(s, now, positions, objects; patrol = true)
    #= none:40 =#
    #= none:41 =#
    prior = s[NID(0x00000000000000ce)]
    #= none:41 =#
    prior !== nothing && (now < prior && error(NID(0x0000000000000374)))
    #= none:42 =#
    prior == now && return
    #= none:44 =#
    times = if prior === nothing
            [now]
        else
            collect(prior + 250000:250000:now)
        end
    #= none:45 =#
    prior !== nothing && (mod(now - prior, 250000) != 0 && error(NID(0x0000000000000375)))
    #= none:46 =#
    for t = times
        #= none:47 =#
        dt = if prior === nothing
                0.0
            else
                0.25
            end
        #= none:48 =#
        blocked = territory_step!(s[NID(0x000000000000029b)], positions, dt, objects)
        #= none:49 =#
        mode = (s[NID(0x000000000000029b)])[NID(0x000000000000029c)]
        #= none:49 =#
        (s[NID(0x0000000000000086)])[mode] = get(s[NID(0x0000000000000086)], mode, 0) + 1
        #= none:50 =#
        if patrol
            #= none:51 =#
            b = s[NID(0x000000000000017b)]
            #= none:51 =#
            p = b[NID(0x000000000000007f)]
            #= none:52 =#
            prior !== nothing && (div(t, 12000000) != div(t - 250000, 12000000) && (b[NID(0x0000000000000356)] = mod(b[NID(0x0000000000000356)] + 90, 360)))
            #= none:53 =#
            q = (p[1] + 1.5 * dt * cosd(b[NID(0x0000000000000356)]), p[2] + 1.5 * dt * sind(b[NID(0x0000000000000356)]))
            #= none:54 =#
            if dt > 0 && any((o->begin
                                #= none:54 =#
                                segment_hit(p, q, o, 0.5)
                            end), objects)
                #= none:55 =#
                b[NID(0x0000000000000356)] = mod(b[NID(0x0000000000000356)] + 90, 360)
            else
                #= none:57 =#
                b[NID(0x000000000000007f)] = q
            end
        end
        #= none:60 =#
        push!(s[NID(0x0000000000000288)], D(NID(0x00000000000002d1) => t, NID(0x000000000000029c) => mode, NID(0x000000000000036a) => blocked, NID(0x000000000000007f) => collect((s[NID(0x000000000000029b)])[NID(0x000000000000007f)])))
        #= none:61 =#
        length(s[NID(0x0000000000000288)]) > 32 && popfirst!(s[NID(0x0000000000000288)])
        #= none:62 =#
    end
    #= none:63 =#
    s[NID(0x00000000000000ce)] = now
end
function dynamic_hazard_sources(s, sec; patrol = true)
    #= none:65 =#
    #= none:66 =#
    bodies = if patrol
            [s[NID(0x000000000000029b)], s[NID(0x000000000000017b)]]
        else
            [s[NID(0x000000000000029b)]]
        end
    #= none:67 =#
    [(x = (b[NID(0x000000000000007f)])[1], z = (b[NID(0x000000000000007f)])[2], vx = 0.0, vz = 0.0, start = sec, stop = sec + 1) for b = bodies]
end
