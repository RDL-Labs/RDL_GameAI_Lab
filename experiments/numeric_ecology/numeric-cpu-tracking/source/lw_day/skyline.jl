# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
prepare_skyline_objects(objects) = begin
        #= none:3 =#
        [(x = Float64(o.x), z = Float64(o.z), radius = Float64(o.radius), height = Float64(o.height), color = NID(o.color)) for o = objects]
    end
function skyline_fan(objects, position, yaw, source; subrays = false)
    #= none:7 =#
    #= none:8 =#
    features = Any[]
    #= none:8 =#
    best = fill(Inf, 3, 13)
    #= none:8 =#
    hits = zeros(Int, 3, 13)
    #= none:9 =#
    for (ai, angle) = enumerate(-90:15:90)
        #= none:10 =#
        for delta = if subrays
                    (-5, 0, 5)
                else
                    (0,)
                end
            #= none:11 =#
            -90 <= angle + delta <= 90 || continue
            #= none:12 =#
            (sn, cs) = sincos(deg2rad(yaw + angle + delta))
            #= none:13 =#
            for (oi, o) = enumerate(objects)
                #= none:14 =#
                d = RDLMigrationProbe.ray_hit(position, (sn, cs), RDLMigrationProbe.Circle(o.x, o.z, o.radius))
                #= none:15 =#
                (d === nothing || d > 48) && continue
                #= none:16 =#
                for (ei, elevation) = enumerate((0, 15, 30))
                    #= none:17 =#
                    if 1 + d * tand(elevation) <= o.height && d < best[ei, ai]
                        #= none:18 =#
                        best[ei, ai] = d
                        #= none:18 =#
                        hits[ei, ai] = oi
                    end
                    #= none:20 =#
                end
                #= none:21 =#
            end
            #= none:22 =#
        end
        #= none:23 =#
    end
    #= none:24 =#
    for (ei, elevation) = enumerate((0, 15, 30)), (ai, angle) = enumerate(-90:15:90)
        #= none:25 =#
        oi = hits[ei, ai]
        #= none:25 =#
        oi == 0 && continue
        #= none:26 =#
        hit = objects[oi]
        #= none:26 =#
        distance = best[ei, ai]
        #= none:27 =#
        push!(features, D(NID(0x0000000000000195) => ncat(NID(0x000000000000039d), elevation, NID(0x00000000000000da), angle), NID(0x000000000000038e) => NID(hit.color), NID(0x000000000000039e) => [max(-90, angle - 7.5), min(90, angle + 7.5)], NID(0x0000000000000396) => elevation, NID(0x000000000000039f) => if distance <= 8
                        NID(0x000000000000023e)
                    else
                        if distance <= 24
                            NID(0x00000000000003a0)
                        else
                            NID(0x00000000000003a1)
                        end
                    end))
        #= none:30 =#
    end
    #= none:31 =#
    D(NID(0x000000000000008d) => NID(0x00000000000003a2), NID(0x0000000000000121) => source, NID(0x000000000000034e) => NID(0x000000000000034f), NID(0x0000000000000341) => features)
end
skyline_state() = begin
        #= none:33 =#
        D(NID(0x00000000000003a3) => nothing, NID(0x00000000000002b2) => 0, NID(0x0000000000000302) => 0, NID(0x000000000000028a) => Any[])
    end
function record_skyline!(s, view)
    #= none:34 =#
    #= none:35 =#
    if s[NID(0x00000000000002b2)] == 0 && view[NID(0x000000000000034e)] == NID(0x000000000000034f)
        #= none:36 =#
        colors = unique([f[NID(0x000000000000038e)] for f = view[NID(0x0000000000000341)] if f[NID(0x000000000000039f)] == NID(0x000000000000023e) && f[NID(0x0000000000000396)] >= 15])
        #= none:37 =#
        length(colors) == 1 && (s[NID(0x00000000000003a3)] = D(NID(0x000000000000038e) => only(colors), NID(0x0000000000000121) => view[NID(0x0000000000000121)]))
    end
    #= none:39 =#
    s[NID(0x00000000000002b2)] += 1
    #= none:39 =#
    push!(s[NID(0x000000000000028a)], view)
    #= none:40 =#
    length(s[NID(0x000000000000028a)]) > 16 && popfirst!(s[NID(0x000000000000028a)])
end
function skyline_home_candidates(s, view, movement)
    #= none:42 =#
    #= none:43 =#
    s[NID(0x00000000000003a3)] === nothing && return Any[]
    #= none:44 =#
    ps = landmark_patches(view, (s[NID(0x00000000000003a3)])[NID(0x000000000000038e)])
    #= none:45 =#
    (ps === nothing || length(ps) != 1) && return Any[]
    #= none:46 =#
    angle = (only(ps))[NID(0x000000000000034a)]
    #= none:47 =#
    rows = [r for r = (movement[NID(0x000000000000030d)])[NID(0x000000000000030e)] if r[NID(0x000000000000030c)] !== nothing]
    #= none:48 =#
    isempty(rows) && return Any[]
    #= none:49 =#
    sort!(rows, by = (r->begin
                    #= none:49 =#
                    (abs(ANGLES[parse(Int, r[NID(0x0000000000000195)]) + 1] - angle), r[NID(0x000000000000030c)], r[NID(0x0000000000000195)])
                end))
    #= none:50 =#
    [D(NID(0x00000000000001b7) => NID(0x0000000000000301), NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => parse(Int, (first(rows))[NID(0x0000000000000195)]), NID(0x00000000000002fe) => 4.0, NID(0x00000000000001b4) => NID(0x00000000000002dd), NID(0x00000000000003a4) => view[NID(0x0000000000000121)])]
end
