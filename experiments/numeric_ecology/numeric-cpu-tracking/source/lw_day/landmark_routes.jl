# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
prepare_landmark_objects(objects) = begin
        #= none:2 =#
        [(x = Float64(o.x), z = Float64(o.z), radius = Float64(o.radius), height = Float64(o.height), color = if hasproperty(o, :color)
                    NID(o.color)
                else
                    NID(0x00000000000005ff)
                end) for o = objects]
    end
function landmark_fan(objects, position, yaw, source)
    #= none:8 =#
    #= none:9 =#
    features = Any[]
    #= none:10 =#
    for angle = -90:15:90
        #= none:11 =#
        (s, c) = sincos(deg2rad(yaw + angle))
        #= none:11 =#
        best = Inf
        #= none:11 =#
        hit = nothing
        #= none:12 =#
        for o = objects
            #= none:13 =#
            d = RDLMigrationProbe.ray_hit(position, (s, c), RDLMigrationProbe.Circle(o.x, o.z, o.radius))
            #= none:14 =#
            if d !== nothing && (d <= 48 && (o.height >= 1 && d < best))
                #= none:15 =#
                best = d
                #= none:15 =#
                hit = o
            end
            #= none:17 =#
        end
        #= none:18 =#
        color = if hit === nothing
                nothing
            else
                if hasproperty(hit, :color)
                    NID(hit.color)
                else
                    NID(0x00000000000005ff)
                end
            end
        #= none:19 =#
        if color !== nothing && color != NID(0x00000000000005ff)
            #= none:20 =#
            push!(features, D(NID(0x000000000000038e) => color, NID(0x000000000000039e) => [max(-90.0, angle - 7.5), min(90.0, angle + 7.5)], NID(0x000000000000039f) => if best <= 8
                            NID(0x000000000000023e)
                        else
                            if best <= 24
                                NID(0x00000000000003a0)
                            else
                                NID(0x00000000000003a1)
                            end
                        end))
        end
        #= none:23 =#
    end
    #= none:24 =#
    D(NID(0x000000000000034e) => NID(0x000000000000034f), NID(0x0000000000000341) => features, NID(0x0000000000000121) => source)
end
function landmark_patches(observed, color)
    #= none:27 =#
    #= none:28 =#
    observed[NID(0x000000000000034e)] == NID(0x000000000000034f) || return nothing
    #= none:29 =#
    fs = sort([f for f = observed[NID(0x0000000000000341)] if f[NID(0x000000000000038e)] == color], by = (f->begin
                        #= none:29 =#
                        (f[NID(0x000000000000039e)])[1]
                    end))
    #= none:30 =#
    groups = Any[]
    #= none:31 =#
    for f = fs
        #= none:32 =#
        (lo, hi) = f[NID(0x000000000000039e)]
        #= none:33 =#
        if !(isempty(groups)) && lo <= (groups[var"end"])[NID(0x00000000000005ef)]
            #= none:34 =#
            (groups[var"end"])[NID(0x00000000000005ef)] = max(hi, (groups[var"end"])[NID(0x00000000000005ef)])
            #= none:35 =#
            (groups[var"end"])[NID(0x000000000000023e)] |= f[NID(0x000000000000039f)] == NID(0x000000000000023e)
        else
            #= none:37 =#
            push!(groups, D(NID(0x00000000000005ee) => lo, NID(0x00000000000005ef) => hi, NID(0x000000000000023e) => f[NID(0x000000000000039f)] == NID(0x000000000000023e)))
        end
        #= none:39 =#
    end
    #= none:40 =#
    [D(NID(0x000000000000034a) => (g[NID(0x00000000000005ee)] + g[NID(0x00000000000005ef)]) / 2, NID(0x000000000000023e) => g[NID(0x000000000000023e)], NID(0x0000000000000600) => g[NID(0x00000000000005ef)] - g[NID(0x00000000000005ee)]) for g = groups]
end
trail() = begin
        #= none:42 =#
        D(NID(0x00000000000003d4) => Any[], NID(0x0000000000000601) => false)
    end
route_memory() = begin
        #= none:43 =#
        D(NID(0x0000000000000132) => D(), NID(0x0000000000000602) => trail(), NID(0x0000000000000603) => nothing, NID(0x00000000000001aa) => false, NID(0x00000000000002ff) => Dict{NID, Int}(), NID(0x0000000000000173) => -1, NID(0x0000000000000302) => 0, NID(0x0000000000000604) => 0, NID(0x000000000000036c) => 0)
    end
function record_landmark!(t, obs, operation; relational = false)
    #= none:46 =#
    #= none:47 =#
    if obs[NID(0x000000000000034e)] != NID(0x000000000000034f)
        #= none:47 =#
        t[NID(0x0000000000000601)] = true
        #= none:47 =#
        return
    end
    #= none:48 =#
    t[NID(0x0000000000000601)] && return
    #= none:49 =#
    candidates = Any[]
    #= none:50 =#
    for color = sort(unique([f[NID(0x000000000000038e)] for f = obs[NID(0x0000000000000341)]]))
        #= none:51 =#
        ps = landmark_patches(obs, color)
        #= none:52 =#
        if length(ps) == 1 && abs((ps[1])[NID(0x000000000000034a)]) <= 45
            #= none:53 =#
            push!(candidates, (abs((ps[1])[NID(0x000000000000034a)]), color))
        end
        #= none:55 =#
    end
    #= none:56 =#
    isempty(candidates) && return
    #= none:57 =#
    sort!(candidates)
    #= none:58 =#
    length(candidates) > 1 && ((candidates[1])[1] == (candidates[2])[1] && return)
    #= none:59 =#
    color = (candidates[1])[2]
    #= none:60 =#
    !(isempty(t[NID(0x00000000000003d4)])) && (((t[NID(0x00000000000003d4)])[var"end"])[NID(0x000000000000038e)] == color && return)
    #= none:61 =#
    if length(t[NID(0x00000000000003d4)]) >= 8
        #= none:61 =#
        t[NID(0x0000000000000601)] = true
        #= none:61 =#
        return
    end
    #= none:62 =#
    point = D(NID(0x000000000000038e) => color, NID(0x0000000000000121) => obs[NID(0x0000000000000121)], NID(0x00000000000003fb) => operation)
    #= none:63 =#
    relational && (point[NID(0x0000000000000044)] = something(relation_scene(obs), Any[]))
    #= none:64 =#
    push!(t[NID(0x00000000000003d4)], point)
end
function admit_route!(memory, goal, t, receipt; relational = false)
    #= none:67 =#
    #= none:68 =#
    (t[NID(0x0000000000000601)] || isempty(t[NID(0x00000000000003d4)])) && return
    #= none:69 =#
    for reverse = (false, true)
        #= none:70 =#
        g = if reverse
                if goal == NID(0x000000000000000d)
                    NID(0x0000000000000096)
                else
                    NID(0x000000000000000d)
                end
            else
                goal
            end
        #= none:71 =#
        points = if reverse
                Base.reverse(t[NID(0x00000000000003d4)])
            else
                t[NID(0x00000000000003d4)]
            end
        #= none:72 =#
        key = g * NID(0x00000000000000da) * njoin([p[NID(0x000000000000038e)] for p = points], NID(0x00000000000003c1))
        #= none:73 =#
        relational && (key *= NID(0x0000000000000165) * (nhex(sha256(njson(relation_signature(points)))))[1:16])
        #= none:74 =#
        if !(haskey(memory[NID(0x0000000000000132)], key))
            #= none:75 =#
            length(memory[NID(0x0000000000000132)]) >= 16 && continue
            #= none:76 =#
            (memory[NID(0x0000000000000132)])[key] = D(NID(0x00000000000001b9) => g, NID(0x00000000000003d4) => deepcopy(points), NID(0x0000000000000605) => 0, NID(0x00000000000001e8) => 0, NID(0x00000000000003ad) => NID[], NID(0x0000000000000606) => NID[])
        end
        #= none:78 =#
        node = (memory[NID(0x0000000000000132)])[key]
        #= none:78 =#
        ids = node[if reverse
                    NID(0x0000000000000606)
                else
                    NID(0x00000000000003ad)
                end]
        #= none:79 =#
        if !(receipt in ids)
            #= none:80 =#
            push!(ids, receipt)
            #= none:80 =#
            length(ids) > 32 && popfirst!(ids)
            #= none:81 =#
            if !reverse
                #= none:81 =#
                node[NID(0x0000000000000605)] = min(8, node[NID(0x0000000000000605)] + 1)
                #= none:81 =#
                node[NID(0x00000000000001e8)] = 0
                #= none:81 =#
                memory[NID(0x0000000000000604)] += 1
            end
        end
        #= none:83 =#
    end
end
function route_result!(m, obs, operation, action, status, goal, at_home, selected_route = nothing; delivered = NID[], relational = false)
    #= none:86 =#
    #= none:87 =#
    at_home && (m[NID(0x0000000000000603)] === nothing && (m[NID(0x00000000000001aa)] = true))
    #= none:88 =#
    if action == NID(0x000000000000030f) && status == NID(0x000000000000029b)
        #= none:89 =#
        if goal == NID(0x000000000000000d) && (m[NID(0x00000000000001aa)] && m[NID(0x0000000000000603)] === nothing)
            #= none:90 =#
            record_landmark!(m[NID(0x0000000000000602)], obs, operation; relational = relational)
        elseif #= none:91 =# goal == NID(0x0000000000000096) && m[NID(0x0000000000000603)] !== nothing
            #= none:92 =#
            record_landmark!((m[NID(0x0000000000000603)])[NID(0x0000000000000607)], obs, operation; relational = relational)
        end
    end
    #= none:95 =#
    if action == NID(0x00000000000002fc) && (status == NID(0x00000000000002e3) && m[NID(0x0000000000000603)] === nothing)
        #= none:96 =#
        m[NID(0x0000000000000603)] = D(NID(0x00000000000002fc) => operation, NID(0x0000000000000602) => if m[NID(0x00000000000001aa)]
                        deepcopy(m[NID(0x0000000000000602)])
                    else
                        nothing
                    end, NID(0x0000000000000607) => trail())
        #= none:97 =#
        m[NID(0x00000000000001aa)] = false
    elseif #= none:98 =# action == NID(0x00000000000002fa) && status == NID(0x000000000000029b)
        #= none:99 =#
        if m[NID(0x0000000000000603)] !== nothing && (m[NID(0x0000000000000603)])[NID(0x00000000000002fc)] in delivered
            #= none:100 =#
            for (g, t) = ((NID(0x000000000000000d), (m[NID(0x0000000000000603)])[NID(0x0000000000000602)]), (NID(0x0000000000000096), (m[NID(0x0000000000000603)])[NID(0x0000000000000607)]))
                #= none:101 =#
                t !== nothing && admit_route!(m, g, t, operation; relational = relational)
                #= none:102 =#
            end
        end
        #= none:104 =#
        m[NID(0x0000000000000603)] = nothing
        #= none:104 =#
        m[NID(0x00000000000001aa)] = true
        #= none:104 =#
        m[NID(0x0000000000000602)] = trail()
        #= none:104 =#
        empty!(m[NID(0x00000000000002ff)])
    end
    #= none:106 =#
    if selected_route !== nothing && status == NID(0x000000000000036c)
        #= none:107 =#
        node = (m[NID(0x0000000000000132)])[selected_route]
        #= none:107 =#
        node[NID(0x00000000000001e8)] = min(32, node[NID(0x00000000000001e8)] + 1)
        #= none:107 =#
        m[NID(0x000000000000036c)] += 1
    end
end
function landmark_candidates(move, obs, m, goal, source; include_routes = true)
    #= none:111 =#
    #= none:112 =#
    obs[NID(0x000000000000034e)] == NID(0x000000000000034f) || return Any[]
    #= none:113 =#
    targets = Any[]
    #= none:114 =#
    for color = sort(unique([f[NID(0x000000000000038e)] for f = obs[NID(0x0000000000000341)]]))
        #= none:115 =#
        ps = landmark_patches(obs, color)
        #= none:116 =#
        if length(ps) == 1 && (!((ps[1])[NID(0x000000000000023e)]) && (ps[1])[NID(0x0000000000000600)] <= 45)
            #= none:117 =#
            push!(targets, D(NID(0x000000000000006e) => NID(0x0000000000000608) * color, NID(0x000000000000038e) => color, NID(0x000000000000034a) => (ps[1])[NID(0x000000000000034a)], NID(0x00000000000002fe) => 2.5, NID(0x000000000000025b) => nothing))
        end
        #= none:119 =#
    end
    #= none:120 =#
    for key = sort(collect(keys(m[NID(0x0000000000000132)])))
        #= none:121 =#
        include_routes || continue
        #= none:122 =#
        n = (m[NID(0x0000000000000132)])[key]
        #= none:122 =#
        n[NID(0x00000000000001b9)] == goal || continue
        #= none:123 =#
        goal == NID(0x000000000000000d) && (!(m[NID(0x00000000000001aa)]) && continue)
        #= none:124 =#
        cursor = get(m[NID(0x00000000000002ff)], key, 1)
        #= none:125 =#
        while cursor <= length(n[NID(0x00000000000003d4)])
            #= none:126 =#
            ps = landmark_patches(obs, ((n[NID(0x00000000000003d4)])[cursor])[NID(0x000000000000038e)])
            #= none:127 =#
            if length(ps) == 1 && (ps[1])[NID(0x000000000000023e)]
                #= none:128 =#
                cursor += 1
            else
                #= none:130 =#
                break
            end
            #= none:132 =#
        end
        #= none:133 =#
        (m[NID(0x00000000000002ff)])[key] = cursor
        #= none:134 =#
        cursor > length(n[NID(0x00000000000003d4)]) && continue
        #= none:135 =#
        color = ((n[NID(0x00000000000003d4)])[cursor])[NID(0x000000000000038e)]
        #= none:135 =#
        ps = landmark_patches(obs, color)
        #= none:136 =#
        length(ps) == 1 || continue
        #= none:137 =#
        push!(targets, D(NID(0x000000000000006e) => NID(0x0000000000000609) * key, NID(0x000000000000038e) => color, NID(0x000000000000034a) => (ps[1])[NID(0x000000000000034a)], NID(0x00000000000002fe) => 2.5 + (1 + 0.25 * n[NID(0x0000000000000605)]) / (1 + n[NID(0x00000000000001e8)]), NID(0x000000000000025b) => key))
        #= none:139 =#
    end
    #= none:140 =#
    out = Any[]
    #= none:141 =#
    for t = targets
        #= none:142 =#
        rows = [r for r = (move[NID(0x000000000000030d)])[NID(0x000000000000030e)] if r[NID(0x000000000000030c)] !== nothing]
        #= none:143 =#
        isempty(rows) && continue
        #= none:144 =#
        sort!(rows, by = (r->begin
                        #= none:144 =#
                        (abs(ANGLES[parse(Int, r[NID(0x0000000000000195)]) + 1] - t[NID(0x000000000000034a)]), r[NID(0x000000000000030c)], r[NID(0x0000000000000195)])
                    end))
        #= none:145 =#
        index = parse(Int, (first(rows))[NID(0x0000000000000195)])
        #= none:146 =#
        push!(out, D(NID(0x00000000000001b7) => t[NID(0x000000000000006e)], NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => index, NID(0x00000000000002fe) => t[NID(0x00000000000002fe)], NID(0x00000000000001b4) => NID(0x00000000000002e1), NID(0x0000000000000339) => t[NID(0x000000000000038e)], NID(0x000000000000025b) => t[NID(0x000000000000025b)], NID(0x00000000000003a4) => source))
        #= none:148 =#
    end
    #= none:149 =#
    out
end
