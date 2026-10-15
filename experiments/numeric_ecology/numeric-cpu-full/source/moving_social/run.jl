# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
include(joinpath(#= none:1 =# @__DIR__(), "../social_loop/run.jl"))
include(joinpath(#= none:2 =# @__DIR__(), "../incremental_aid/state.jl"))
function moving_world(spec)
    #= none:4 =#
    #= none:5 =#
    w = world(spec.hearing)
    #= none:5 =#
    w.capacity = 4096
    #= none:6 =#
    for (i, a) = enumerate(IDS)
        #= none:7 =#
        w.positions[a] = (Float64((spec.positions[i])[1]), Float64((spec.positions[i])[2]))
        #= none:8 =#
        w.bodies[a] = Body(10.0, 0.0, if a == NID(0x00000000000004c9)
                    50.0
                else
                    100.0
                end, 0.0)
        #= none:9 =#
    end
    #= none:10 =#
    w.obstacles = [RDLMigrationProbe.Circle(o.x, o.z, o.radius) for o = spec.obstacles]
    #= none:11 =#
    w
end
function movement_observation(w, actor, yaw, food, stock; resistance_at = (p->begin
                    #= none:14 =#
                    1.5
                end), run_resistance_at = resistance_at, running = false, visual_obstacles = w.obstacles)
    #= none:14 =#
    #= none:15 =#
    origin = w.positions[actor]
    #= none:15 =#
    (s, c) = sincos(deg2rad(yaw[actor]))
    #= none:15 =#
    visible = Any[]
    #= none:16 =#
    for (j, f) = enumerate(food)
        #= none:17 =#
        (dx, dz) = (f.x - origin[1], f.z - origin[2])
        #= none:17 =#
        (forward, right) = (dx * s + dz * c, dx * c - dz * s)
        #= none:18 =#
        distance = hypot(forward, right)
        #= none:19 =#
        if stock[j] > 0 && (distance <= 12 && (forward >= 0 && !(any((o->begin
                                        #= none:19 =#
                                        segment_hit(origin, (Float64(f.x), Float64(f.z)), o, 0.0)
                                    end), visual_obstacles))))
            #= none:20 =#
            push!(visible, D(NID(0x0000000000000195) => j - 1, NID(0x0000000000000279) => forward, NID(0x000000000000027a) => right, NID(0x0000000000000084) => distance, NID(0x0000000000000330) => if hasproperty(f, :appearance)
                            f.appearance
                        else
                            NID(0x00000000000004ca)
                        end))
        end
        #= none:23 =#
    end
    #= none:24 =#
    food_coverage = if length(visible) > 5
            NID(0x0000000000000382)
        else
            NID(0x000000000000034d)
        end
    #= none:25 =#
    sort!(visible, by = (v->begin
                    #= none:25 =#
                    (v[NID(0x0000000000000084)], v[NID(0x0000000000000195)])
                end))
    #= none:25 =#
    resize!(visible, min(5, length(visible)))
    #= none:26 =#
    target = if isempty(visible)
            nothing
        else
            visible[1]
        end
    #= none:26 =#
    rows = Any[]
    #= none:26 =#
    surface = Any[]
    #= none:26 =#
    chosen = nothing
    #= none:26 =#
    best = Inf
    #= none:27 =#
    b = w.bodies[actor]
    #= none:28 =#
    for (j, angle) = enumerate(ANGLES)
        #= none:29 =#
        theta = deg2rad(yaw[actor] + angle)
        #= none:29 =#
        endpoint = (origin[1] + sin(theta), origin[2] + cos(theta))
        #= none:30 =#
        clear = !(any((o->begin
                            #= none:30 =#
                            segment_hit(origin, endpoint, o, 0.2)
                        end), w.obstacles))
        #= none:33 =#
        push!(surface, D(NID(0x0000000000000387) => angle, NID(0x000000000000008a) => if clear
                        NID(0x0000000000000385)
                    else
                        NID(0x000000000000036a)
                    end, NID(0x0000000000000386) => if clear
                        0.0
                    else
                        nothing
                    end))
        #= none:35 =#
        goal = if target === nothing
                1.0 + abs(angle) / 90
            else
                min(10.0, hypot(target[NID(0x0000000000000279)] - cos(deg2rad(Float64(angle))), target[NID(0x000000000000027a)] - sin(deg2rad(Float64(angle)))))
            end
        #= none:36 =#
        midpoint = (origin[1] + sin(theta) * 0.25 * (1 - b.damage), origin[2] + cos(theta) * 0.25 * (1 - b.damage))
        #= none:37 =#
        resistance = resistance_at(midpoint)
        #= none:38 =#
        (_, status, _, delta) = step(b, NID(0x000000000000030d), w.inventory[actor], resistance, clear)
        #= none:39 =#
        cost = if status == NID(0x0000000000000299)
                ((goal - delta[NID(0x000000000000014e)] / max(b.reserve, 0.001)) - delta[NID(0x0000000000000257)] / max(b.burst, 0.001)) + delta[NID(0x00000000000001dc)]
            else
                nothing
            end
        #= none:40 =#
        if cost !== nothing && cost < best
            #= none:41 =#
            best = cost
            #= none:41 =#
            chosen = ncat(j - 1)
        end
        #= none:43 =#
        push!(rows, D(NID(0x0000000000000195) => ncat(j - 1), NID(0x000000000000021f) => NID(0x000000000000030d), NID(0x000000000000022e) => clear, NID(0x0000000000000231) => resistance, NID(0x0000000000000316) => w.inventory[actor], NID(0x00000000000004cb) => goal, NID(0x000000000000008a) => status, NID(0x000000000000030a) => cost, NID(0x0000000000000317) => delta))
        #= none:45 =#
    end
    #= none:46 =#
    run_rows = Any[]
    #= none:47 =#
    if running
        #= none:48 =#
        for (j, angle) = enumerate(ANGLES)
            #= none:49 =#
            theta = deg2rad(yaw[actor] + angle)
            #= none:49 =#
            distance = 1.5 * (1 - b.damage)
            #= none:50 =#
            endpoint = (origin[1] + sin(theta) * distance, origin[2] + cos(theta) * distance)
            #= none:51 =#
            midpoint = ((origin[1] + endpoint[1]) / 2, (origin[2] + endpoint[2]) / 2)
            #= none:52 =#
            clear = !(any((o->begin
                                #= none:52 =#
                                segment_hit(origin, endpoint, o, 0.2)
                            end), w.obstacles))
            #= none:53 =#
            resistance = run_resistance_at(midpoint)
            #= none:54 =#
            (_, status, d, delta) = step(b, NID(0x000000000000031a), w.inventory[actor], resistance, clear)
            #= none:55 =#
            push!(run_rows, D(NID(0x0000000000000195) => ncat(j - 1), NID(0x000000000000021f) => NID(0x000000000000031a), NID(0x000000000000022e) => clear, NID(0x0000000000000231) => resistance, NID(0x0000000000000316) => w.inventory[actor], NID(0x000000000000008a) => status, NID(0x000000000000030a) => if status == NID(0x0000000000000299)
                            -(delta[NID(0x000000000000014e)])
                        else
                            nothing
                        end, NID(0x0000000000000084) => d, NID(0x0000000000000317) => delta))
            #= none:58 =#
        end
    end
    #= none:60 =#
    D(NID(0x0000000000000383) => D(NID(0x00000000000004cc) => NID(0x00000000000004cd), NID(0x0000000000000036) => D(NID(0x000000000000034c) => NID(0x000000000000034d), NID(0x0000000000000384) => false, NID(0x0000000000000357) => surface)), NID(0x0000000000000381) => food_coverage, NID(0x000000000000031d) => run_rows, NID(0x00000000000001dd) => visible, NID(0x000000000000030b) => D(NID(0x00000000000000c6) => NID(0x00000000000004ce), NID(0x000000000000030c) => rows, NID(0x0000000000000302) => chosen, NID(0x000000000000021f) => if chosen === nothing
                        NID(0x00000000000002f0)
                    else
                        NID(0x000000000000030d)
                    end, NID(0x000000000000008a) => if chosen === nothing
                        NID(0x00000000000004cf)
                    else
                        NID(0x0000000000000302)
                    end))
end
function moving_scenario(spec; incremental = false, recording = :detailed)
    #= none:66 =#
    #= none:67 =#
    check(recording in (:detailed, :compact), NID(0x00000000000004d0))
    #= none:68 =#
    w = moving_world(spec)
    #= none:68 =#
    yaw = Dict((a => 0.0 for a = IDS))
    #= none:68 =#
    stock = Int[f.stock for f = spec.food]
    #= none:69 =#
    states = D((a => social_initial() for a = IDS))
    #= none:69 =#
    pressures = D((a => pressure_update(nothing, D(), a, 3) for a = IDS))
    #= none:70 =#
    live = Dict((a => live_aid(a) for a = IDS))
    #= none:71 =#
    results = D((a => D() for a = IDS))
    #= none:71 =#
    answered = Dict((a => Set{NID}() for a = IDS))
    #= none:72 =#
    rows = Any[]
    #= none:72 =#
    nights = Any[]
    #= none:72 =#
    effects = D()
    #= none:72 =#
    requests = Dict((a => 0 for a = IDS))
    #= none:73 =#
    transitions = Any[]
    #= none:73 =#
    previous = Dict{NID, Any}()
    #= none:73 =#
    counts = Dict((a => Dict{NID, Int}() for a = IDS))
    #= none:74 =#
    function actor_state(actor)
        #= none:74 =#
        #= none:75 =#
        p = w.positions[actor]
        #= none:76 =#
        D(NID(0x000000000000007f) => D(NID(0x00000000000000d1) => p[1], NID(0x00000000000000e3) => p[2], NID(0x0000000000000095) => yaw[actor]), NID(0x0000000000000080) => bodydict(w.bodies[actor]), NID(0x0000000000000081) => w.inventory[actor])
    end
    #= none:79 =#
    function integrate(actor, now, obs)
        #= none:79 =#
        #= none:80 =#
        p = D(NID(0x00000000000002cb) => actor, NID(0x00000000000002cc) => now, NID(0x00000000000002cd) => ncat(NID(0x00000000000002ce), now, NID(0x00000000000000da), actor), NID(0x00000000000002cf) => obs)
        #= none:81 =#
        count_before = length((states[actor])[NID(0x0000000000000288)])
        #= none:82 =#
        states[actor] = ingest(states[actor], p, results[actor])
        #= none:83 =#
        if incremental
            #= none:84 =#
            records = (states[actor])[NID(0x0000000000000288)]
            #= none:86 =#
            pressures[actor] = pressure_poll!(live[actor], records, count_before)
        else
            #= none:88 =#
            pressures[actor] = pressure_update(pressures[actor], (states[actor])[NID(0x0000000000000288)], actor, 3)
        end
    end
    #= none:91 =#
    function execute(actor, op, plan)
        #= none:91 =#
        #= none:92 =#
        if haskey(effects, op)
            #= none:93 =#
            (old, r) = effects[op]
            #= none:93 =#
            check(old == plan, NID(0x00000000000004d1))
            #= none:93 =#
            return deepcopy(r)
        end
        #= none:95 =#
        action = plan[NID(0x000000000000021f)]
        #= none:95 =#
        origin = w.positions[actor]
        #= none:96 =#
        if action in (NID(0x00000000000002e6), NID(0x00000000000002a9), NID(0x00000000000002aa), NID(0x00000000000002e7), NID(0x000000000000031f), NID(0x00000000000002ee), NID(0x0000000000000320))
            #= none:97 =#
            r = communicate!(w, actor, op, action, get(plan, NID(0x00000000000001b0), nothing), get(plan, NID(0x00000000000002ed), nothing))
        elseif #= none:98 =# action == NID(0x00000000000002fa)
            #= none:99 =#
            j = plan[NID(0x00000000000002fb)] + 1
            #= none:99 =#
            f = spec.food[j]
            #= none:100 =#
            legal = stock[j] > 0 && (hypot(f.x - origin[1], f.z - origin[2]) <= 1.25 && !(any((o->begin
                                        #= none:100 =#
                                        segment_hit(origin, (Float64(f.x), Float64(f.z)), o, 0.0)
                                    end), w.obstacles)))
            #= none:101 =#
            if legal
                #= none:102 =#
                stock[j] -= 1
                #= none:102 =#
                w.inventory[actor] += 1
            end
            #= none:104 =#
            r = D(NID(0x000000000000008a) => if legal
                            NID(0x00000000000002e1)
                        else
                            NID(0x0000000000000324)
                        end)
        elseif #= none:105 =# action == NID(0x000000000000030d)
            #= none:106 =#
            yaw[actor] = mod(yaw[actor] + ANGLES[plan[NID(0x0000000000000251)] + 1] + 180, 360) - 180
            #= none:107 =#
            (dx, dz) = sincos(deg2rad(yaw[actor]))
            #= none:107 =#
            b = w.bodies[actor]
            #= none:108 =#
            endpoint = (origin[1] + dx * 0.5 * (1 - b.damage), origin[2] + dz * 0.5 * (1 - b.damage))
            #= none:109 =#
            clear = !(any((o->begin
                                #= none:109 =#
                                segment_hit(origin, endpoint, o, 0.2)
                            end), w.obstacles))
            #= none:110 =#
            (w.bodies[actor], status, distance, _) = step(b, NID(0x000000000000030d), w.inventory[actor], 1.5, clear)
            #= none:111 =#
            w.positions[actor] = (origin[1] + dx * distance, origin[2] + dz * distance)
            #= none:112 =#
            r = D(NID(0x000000000000008a) => status, NID(0x0000000000000084) => distance)
        else
            #= none:114 =#
            (w.bodies[actor], status, _, _) = step(w.bodies[actor], NID(0x00000000000002f0), w.inventory[actor])
            #= none:114 =#
            r = D(NID(0x000000000000008a) => status)
        end
        #= none:116 =#
        effects[op] = (deepcopy(plan), deepcopy(r))
        #= none:116 =#
        r
    end
    #= none:118 =#
    for day = 0:2
        #= none:119 =#
        b = w.bodies[NID(0x00000000000004c9)]
        #= none:119 =#
        w.bodies[NID(0x00000000000004c9)] = Body(b.burst, b.strain, max(0.0, b.reserve - 20), b.damage)
        #= none:120 =#
        for tick = 0:spec.ticks - 1
            #= none:121 =#
            now = day * DAY + tick * 1000000
            #= none:121 =#
            w.seconds = now / 1.0e6
            #= none:122 =#
            observations = D((a => observe(w, a) for a = IDS))
            #= none:123 =#
            moves = D((a => movement_observation(w, a, yaw, spec.food, stock) for a = IDS))
            #= none:123 =#
            plans = D()
            #= none:123 =#
            selections = D()
            #= none:124 =#
            for actor = IDS
                #= none:125 =#
                obs = observations[actor]
                #= none:125 =#
                integrate(actor, now, obs)
                #= none:125 =#
                s = states[actor]
                #= none:126 =#
                messages = [m for m = reverse(obs[NID(0x00000000000001c3)]) if !(m[NID(0x0000000000000237)] in answered[actor]) && m[NID(0x000000000000024d)] in (NID(0x00000000000002e6), NID(0x00000000000002e7), NID(0x00000000000002e8))]
                #= none:127 =#
                plan = nothing
                #= none:128 =#
                if !(isempty(messages))
                    #= none:129 =#
                    m = messages[1]
                    #= none:129 =#
                    (act, t, r) = response(merge(copy(obs), D(NID(0x00000000000001c3) => [m])), actor != NID(0x00000000000002ec))
                    #= none:130 =#
                    plan = D(NID(0x000000000000021f) => act, NID(0x00000000000001b0) => t, NID(0x00000000000002ed) => r)
                    #= none:130 =#
                    push!(answered[actor], m[NID(0x0000000000000237)])
                elseif #= none:131 =# obs[NID(0x0000000000000081)] > 0 && (obs[NID(0x0000000000000080)])[NID(0x000000000000014e)] < 80
                    #= none:132 =#
                    plan = D(NID(0x000000000000021f) => NID(0x00000000000002ee))
                elseif #= none:133 =# s[NID(0x0000000000000145)] !== nothing
                    #= none:134 =#
                    plan = D(NID(0x000000000000021f) => NID(0x00000000000002f0))
                elseif #= none:135 =# (obs[NID(0x0000000000000080)])[NID(0x000000000000014e)] < 80
                    #= none:136 =#
                    targets = [o[NID(0x0000000000000195)] for o = obs[NID(0x00000000000002f2)] if o[NID(0x00000000000002f1)]]
                    #= none:137 =#
                    (target, selections[actor]) = select_target(targets, s[NID(0x000000000000008d)], pressures[actor])
                    #= none:138 =#
                    if target !== nothing
                        #= none:139 =#
                        plan = D(NID(0x000000000000021f) => NID(0x00000000000002e6), NID(0x00000000000001b0) => target)
                        #= none:139 =#
                        op = ncat(NID(0x00000000000002e9), now, NID(0x00000000000000da), actor)
                        #= none:140 =#
                        s[NID(0x0000000000000145)] = D(NID(0x00000000000002f4) => actor * NID(0x00000000000000da) * op, NID(0x00000000000001b0) => target, NID(0x00000000000002f5) => now + 5000000, NID(0x00000000000002f6) => ncat(NID(0x00000000000002ce), now, NID(0x00000000000000da), actor), NID(0x00000000000002f7) => op)
                        #= none:142 =#
                        requests[actor] += 1
                    end
                end
                #= none:145 =#
                if plan === nothing
                    #= none:146 =#
                    visible = (moves[actor])[NID(0x00000000000001dd)]
                    #= none:146 =#
                    chosen = ((moves[actor])[NID(0x000000000000030b)])[NID(0x0000000000000302)]
                    #= none:147 =#
                    if !(isempty(visible)) && (visible[1])[NID(0x0000000000000084)] <= 1.25
                        #= none:148 =#
                        plan = D(NID(0x000000000000021f) => NID(0x00000000000002fa), NID(0x00000000000002fb) => (visible[1])[NID(0x0000000000000195)])
                    elseif #= none:149 =# obs[NID(0x0000000000000081)] > 0 || chosen === nothing
                        #= none:150 =#
                        plan = D(NID(0x000000000000021f) => NID(0x00000000000002f0))
                    else
                        #= none:152 =#
                        plan = D(NID(0x000000000000021f) => NID(0x000000000000030d), NID(0x0000000000000251) => parse(Int, chosen))
                    end
                end
                #= none:155 =#
                plans[actor] = plan
                #= none:156 =#
            end
            #= none:157 =#
            w.seconds = (now + 1000000) / 1.0e6
            #= none:158 =#
            for actor = IDS
                #= none:159 =#
                op = ncat(NID(0x00000000000002e9), now, NID(0x00000000000000da), actor)
                #= none:159 =#
                r = execute(actor, op, plans[actor])
                #= none:160 =#
                saved = deepcopy((w.inventory, w.bodies, w.positions, yaw, stock, w.consumed))
                #= none:161 =#
                #= none:161 =# @assert execute(actor, op, plans[actor]) == r
                #= none:162 =#
                #= none:162 =# @assert saved == (w.inventory, w.bodies, w.positions, yaw, stock, w.consumed)
                #= none:163 =#
                (results[actor])[op] = r
                #= none:163 =#
                p = w.positions[actor]
                #= none:164 =#
                if recording == :compact
                    #= none:165 =#
                    action = (plans[actor])[NID(0x000000000000021f)]
                    #= none:166 =#
                    (counts[actor])[action] = get(counts[actor], action, 0) + 1
                    #= none:167 =#
                    signature = (day, action, get(plans[actor], NID(0x00000000000001b0), nothing), get(plans[actor], NID(0x0000000000000251), nothing), get(plans[actor], NID(0x00000000000002fb), nothing), get(r, NID(0x000000000000008a), nothing))
                    #= none:169 =#
                    if get(previous, actor, nothing) != signature
                        #= none:170 =#
                        push!(transitions, D(NID(0x0000000000000173) => day, NID(0x00000000000004be) => tick, NID(0x0000000000000259) => actor, NID(0x00000000000001a9) => copy(plans[actor]), NID(0x000000000000008a) => get(r, NID(0x000000000000008a), nothing)))
                        #= none:172 =#
                        previous[actor] = signature
                    end
                    #= none:174 =#
                    if action == NID(0x00000000000002e6)
                        #= none:175 =#
                        #= none:175 =# @assert (plans[actor])[NID(0x00000000000001b0)] in [o[NID(0x0000000000000195)] for o = (observations[actor])[NID(0x00000000000002f2)] if o[NID(0x00000000000002f1)]]
                    end
                    #= none:177 =#
                    continue
                end
                #= none:179 =#
                push!(rows, D(NID(0x0000000000000173) => day, NID(0x00000000000004be) => tick, NID(0x0000000000000259) => actor, NID(0x00000000000003e4) => observations[actor], NID(0x0000000000000345) => moves[actor], NID(0x00000000000001a9) => plans[actor], NID(0x00000000000004d2) => get(selections, actor, nothing), NID(0x00000000000003f9) => r, NID(0x000000000000007f) => D(NID(0x00000000000000d1) => p[1], NID(0x00000000000000e3) => p[2], NID(0x0000000000000095) => yaw[actor]), NID(0x0000000000000080) => bodydict(w.bodies[actor]), NID(0x0000000000000081) => copy(w.inventory), NID(0x0000000000000082) => copy(stock), NID(0x00000000000002cf) => deepcopy(states[actor]), NID(0x000000000000042b) => if incremental
                                pressure_snapshot(live[actor])
                            else
                                deepcopy(pressures[actor])
                            end))
                #= none:184 =#
            end
            #= none:185 =#
            #= none:185 =# @assert sum(stock) + sum(values(w.inventory)) + w.consumed == 60
            #= none:186 =#
        end
        #= none:187 =#
        start = day * DAY + 14400000000
        #= none:187 =#
        w.seconds = start / 1.0e6
        #= none:187 =#
        night = D()
        #= none:188 =#
        for actor = IDS
            #= none:189 =#
            integrate(actor, start, observe(w, actor))
            #= none:189 =#
            learning = sleeper(day)
            #= none:190 =#
            for sec = 0:2879
                #= none:191 =#
                phase = if spec.interrupt && sec == 100
                        NID(0x000000000000007b)
                    else
                        NID(0x00000000000002d4)
                    end
                #= none:192 =#
                (w.bodies[actor], _, _, _) = step(w.bodies[actor], NID(0x00000000000002f0), w.inventory[actor])
                #= none:193 =#
                receipt!(learning, start + sec * 1000000; phase = phase)
                #= none:194 =#
            end
            #= none:195 =#
            cycle = (learning[NID(0x0000000000000088)])[NID(0x0000000000000089)]
            #= none:196 =#
            spec.adopt && (states[actor] = consolidate_social(states[actor], merge(copy(cycle), D(NID(0x000000000000032d) => start)), actor))
            #= none:197 =#
            night[actor] = merge(D(NID(0x0000000000000088) => learning[NID(0x0000000000000088)], NID(0x00000000000002cf) => deepcopy(states[actor])), actor_state(actor))
            #= none:198 =#
        end
        #= none:199 =#
        push!(nights, night)
        #= none:200 =#
    end
    #= none:201 =#
    output = D(NID(0x000000000000030c) => rows, NID(0x00000000000004b8) => nights, NID(0x00000000000004d3) => requests, NID(0x0000000000000076) => w.consumed, NID(0x0000000000000082) => stock, NID(0x0000000000000081) => w.inventory, NID(0x000000000000007d) => D((a => actor_state(a) for a = IDS)))
    #= none:203 =#
    if recording == :compact
        #= none:204 =#
        output[NID(0x00000000000004ba)] = transitions
        #= none:204 =#
        output[NID(0x00000000000004d4)] = counts
        #= none:205 =#
        output[NID(0x00000000000004b3)] = NID(0x00000000000004d5)
    end
    #= none:207 =#
    output
end
function contact_boundaries(spec)
    #= none:210 =#
    #= none:211 =#
    w = moving_world(spec)
    #= none:211 =#
    w.positions[NID(0x00000000000004c9)] = (0.0, 0.0)
    #= none:211 =#
    w.positions[NID(0x00000000000002ec)] = (0.0, 1.0)
    #= none:212 =#
    out = D(NID(0x000000000000023e) => contact(w, NID(0x00000000000004c9), NID(0x00000000000002ec)))
    #= none:213 =#
    w.positions[NID(0x00000000000002ec)] = (0.0, 2.0)
    #= none:213 =#
    out[NID(0x000000000000039f)] = contact(w, NID(0x00000000000004c9), NID(0x00000000000002ec))
    #= none:214 =#
    w.positions[NID(0x00000000000002ec)] = (0.0, 1.0)
    #= none:214 =#
    w.obstacles = [RDLMigrationProbe.Circle(0.0, 0.5, 0.1)]
    #= none:215 =#
    out[NID(0x00000000000003e0)] = contact(w, NID(0x00000000000004c9), NID(0x00000000000002ec))
    #= none:215 =#
    empty!(w.obstacles)
    #= none:216 =#
    communicate!(w, NID(0x00000000000004c9), NID(0x00000000000002e6), NID(0x00000000000002e6), NID(0x00000000000002ec))
    #= none:216 =#
    w.seconds = 1.0
    #= none:217 =#
    w.positions[NID(0x00000000000002ec)] = (0.0, 2.0)
    #= none:218 =#
    out[NID(0x00000000000004d6)] = communicate!(w, NID(0x00000000000002ec), NID(0x00000000000001d2), NID(0x00000000000002a9), NID(0x00000000000004c9), NID(0x00000000000004d7))
    #= none:219 =#
    out[NID(0x00000000000004d8)] = copy(w.inventory)
    #= none:220 =#
    w.positions[NID(0x00000000000002ec)] = (0.0, 1.0)
    #= none:220 =#
    out[NID(0x00000000000004d9)] = contact(w, NID(0x00000000000004c9), NID(0x00000000000002ec))
    #= none:221 =#
    out[NID(0x00000000000004da)] = communicate!(w, NID(0x00000000000002ec), NID(0x00000000000001d2), NID(0x00000000000002a9), NID(0x00000000000004c9), NID(0x00000000000004d7))
    #= none:222 =#
    out[NID(0x00000000000004db)] = communicate!(w, NID(0x00000000000002ec), NID(0x00000000000004dc), NID(0x00000000000002a9), NID(0x00000000000004c9), NID(0x00000000000004d7))
    #= none:223 =#
    out[NID(0x00000000000004dd)] = copy(w.inventory)
    #= none:224 =#
    try
        #= none:224 =#
        communicate!(w, NID(0x00000000000002ec), NID(0x00000000000004dc), NID(0x00000000000002aa), NID(0x00000000000004c9), NID(0x00000000000004d7))
    catch e
        #= none:224 =#
        out[NID(0x00000000000004de)] = e.msg
    end
    #= none:225 =#
    out
end
nothing
