# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
include(joinpath(#= none:1 =# @__DIR__(), "../all_loop/loop.jl"))
include(joinpath(#= none:2 =# @__DIR__(), "models.jl"))
const IDS = Tuple(((NID(0x00000000000004cb), NID(0x00000000000002ee), NID(0x00000000000004f8), NID(0x00000000000004f9), NID(0x00000000000004fa), NID(0x00000000000004fb), NID(0x00000000000004fc), NID(0x00000000000004fd), NID(0x00000000000004fe), NID(0x00000000000004ff), NID(0x0000000000000500), NID(0x0000000000000501), NID(0x0000000000000502), NID(0x0000000000000503), NID(0x0000000000000504), NID(0x0000000000000505), NID(0x0000000000000506), NID(0x0000000000000507), NID(0x0000000000000508), NID(0x0000000000000509), NID(0x000000000000050a), NID(0x000000000000050b), NID(0x000000000000050c), NID(0x000000000000050d), NID(0x000000000000050e), NID(0x000000000000050f), NID(0x0000000000000510), NID(0x0000000000000511), NID(0x0000000000000512), NID(0x0000000000000513)))[1:NumericCore.AGENT_COUNT[]])
include(joinpath(#= none:5 =# @__DIR__(), "numeric_storage.jl"))
mutable struct ContactWorld
    #= none:7 =#
    inventory::AgentSlots{Int}
    #= none:8 =#
    bodies::AgentSlots{Body}
    #= none:9 =#
    inbox::AgentSlots{Vector{Any}}
    #= none:10 =#
    hearing::AgentSlots{Bool}
    #= none:11 =#
    receipts::D
    #= none:12 =#
    answered::Set{Tuple{NID, NID}}
    #= none:13 =#
    seconds::Float64
    #= none:14 =#
    consumed::Int
    #= none:15 =#
    positions::AgentSlots{Tuple{Float64, Float64}}
    #= none:16 =#
    obstacles::Vector{RDLMigrationProbe.Circle}
    #= none:17 =#
    capacity::Int
end
function ContactWorld(inventory::Dict, bodies::Dict, inbox::Dict, hearing::Dict, receipts, answered, seconds, consumed, positions::Dict, obstacles, capacity)
    #= none:19 =#
    #= none:20 =#
    ContactWorld(AgentSlots(inventory), AgentSlots(bodies), AgentSlots(inbox), AgentSlots(hearing), receipts, answered, seconds, consumed, AgentSlots(positions), obstacles, capacity)
end
function world(hearing)
    #= none:22 =#
    #= none:23 =#
    ContactWorld(Dict((a => if a == NID(0x00000000000004cb)
                    0
                else
                    12
                end for a = IDS)), Dict((a => Body(10.0, 0.0, 50.0, 0.0) for a = IDS)), Dict((a => Any[] for a = IDS)), Dict((a => a != NID(0x00000000000002ee) || hearing for a = IDS)), D(), Set{Tuple{NID, NID}}(), 0.0, 0, Dict((a => ((i - 1) * 0.4, 0.0) for (i, a) = enumerate(IDS))), RDLMigrationProbe.Circle[], 256)
end
function contact(w, a, b)
    #= none:28 =#
    #= none:29 =#
    b in IDS && b != a || return false
    #= none:30 =#
    (p, q) = (w.positions[a], w.positions[b])
    #= none:31 =#
    hypot(q[1] - p[1], q[2] - p[2]) <= 1.25 && !(any((o->begin
                        #= none:31 =#
                        segment_hit(p, q, o, 0.0)
                    end), w.obstacles))
end
function observe(w, a)
    #= none:33 =#
    #= none:34 =#
    D(NID(0x000000000000043f) => a, NID(0x0000000000000080) => bodydict(w.bodies[a]), NID(0x0000000000000081) => w.inventory[a], NID(0x00000000000002f4) => [D(NID(0x0000000000000195) => b, NID(0x00000000000002f3) => w.inventory[b] > 0) for b = IDS if contact(w, a, b)], NID(0x00000000000001c3) => deepcopy([m for m = w.inbox[a] if 0 <= w.seconds - m[NID(0x0000000000000164)] < 3]))
end
function communicate!(w, a, op, action, target = nothing, reply = nothing)
    #= none:38 =#
    #= none:39 =#
    key = a * NID(0x000000000000043b) * op
    #= none:39 =#
    request = (action, target, reply)
    #= none:40 =#
    if haskey(w.receipts, key)
        #= none:41 =#
        (old, result) = w.receipts[key]
        #= none:41 =#
        check(old == request, NID(0x0000000000000514))
        #= none:41 =#
        return deepcopy(result)
    end
    #= none:43 =#
    check(a in IDS && !(isempty(op)), NID(0x0000000000000515))
    #= none:43 =#
    check(length(w.receipts) < w.capacity, NID(0x00000000000000ac))
    #= none:44 =#
    check(action in (NID(0x00000000000002e8), NID(0x00000000000002ab), NID(0x00000000000002ac), NID(0x00000000000002ea), NID(0x00000000000002e9), NID(0x0000000000000321), NID(0x00000000000002f0), NID(0x0000000000000322)), NID(0x000000000000021f))
    #= none:45 =#
    check(target === nothing || target in IDS && target != a, NID(0x00000000000001b0))
    #= none:46 =#
    messages = (observe(w, a))[NID(0x00000000000001c3)]
    #= none:47 =#
    predecessors = [m for m = messages if m[NID(0x0000000000000237)] == reply && m[NID(0x0000000000000442)] == target]
    #= none:48 =#
    antecedent = if isempty(predecessors)
            nothing
        else
            predecessors[1]
        end
    #= none:49 =#
    status = NID(0x0000000000000327)
    #= none:49 =#
    kind = nothing
    #= none:50 =#
    if action in (NID(0x0000000000000322), NID(0x0000000000000321))
        #= none:51 =#
        status = action
    elseif #= none:52 =# action == NID(0x00000000000002f0)
        #= none:53 =#
        if w.inventory[a] > 0
            #= none:54 =#
            (w.bodies[a], status, _, _) = step(w.bodies[a], NID(0x00000000000002f0), 0)
            #= none:55 =#
            w.inventory[a] -= 1
            #= none:55 =#
            w.consumed += 1
        else
            #= none:57 =#
            status = NID(0x0000000000000516)
        end
    elseif #= none:59 =# target !== nothing && contact(w, a, target)
        #= none:60 =#
        if action in (NID(0x00000000000002e8), NID(0x00000000000002ea))
            #= none:61 =#
            kind = action
            #= none:61 =#
            status = NID(0x0000000000000517)
        elseif #= none:62 =# action in (NID(0x00000000000002ab), NID(0x00000000000002ac)) && (antecedent !== nothing && (antecedent[NID(0x000000000000024d)] == NID(0x00000000000002e8) && !((a, reply) in w.answered)))
            #= none:63 =#
            if action == NID(0x00000000000002ac)
                #= none:64 =#
                kind = NID(0x00000000000002ac)
                #= none:64 =#
                status = NID(0x0000000000000517)
            elseif #= none:65 =# w.inventory[a] > 0
                #= none:66 =#
                w.inventory[a] -= 1
                #= none:66 =#
                w.inventory[target] += 1
                #= none:66 =#
                kind = NID(0x0000000000000518)
                #= none:66 =#
                status = NID(0x0000000000000324)
            end
        elseif #= none:68 =# action == NID(0x00000000000002e9) && (antecedent !== nothing && antecedent[NID(0x000000000000024d)] == NID(0x00000000000002ea))
            #= none:69 =#
            kind = NID(0x00000000000002e9)
            #= none:69 =#
            status = NID(0x0000000000000517)
        end
    end
    #= none:72 =#
    kind in (NID(0x0000000000000518), NID(0x00000000000002ac)) && push!(w.answered, (a, reply))
    #= none:73 =#
    if kind !== nothing && (kind in (NID(0x00000000000002ea), NID(0x0000000000000518)) || w.hearing[target])
        #= none:74 =#
        w.inbox[target] = [m for m = w.inbox[target] if w.seconds - m[NID(0x0000000000000164)] < 3]
        #= none:75 =#
        push!(w.inbox[target], D(NID(0x0000000000000237) => a * NID(0x00000000000000da) * op, NID(0x0000000000000442) => a, NID(0x000000000000024d) => kind, NID(0x00000000000002ef) => reply, NID(0x0000000000000164) => w.seconds))
    end
    #= none:77 =#
    r = D(NID(0x00000000000003b0) => a, NID(0x0000000000000328) => op, NID(0x000000000000021f) => action, NID(0x000000000000008a) => status, NID(0x0000000000000164) => w.seconds)
    #= none:78 =#
    w.receipts[key] = (request, deepcopy(r))
    #= none:78 =#
    r
end
function response(obs, share)
    #= none:80 =#
    #= none:81 =#
    for m = reverse(obs[NID(0x00000000000001c3)])
        #= none:82 =#
        action = if m[NID(0x000000000000024d)] == NID(0x00000000000002e9)
                NID(0x0000000000000321)
            else
                if m[NID(0x000000000000024d)] == NID(0x00000000000002ea)
                    NID(0x00000000000002e9)
                else
                    if m[NID(0x000000000000024d)] == NID(0x00000000000002e8)
                        if share && obs[NID(0x0000000000000081)] > 0
                            NID(0x00000000000002ab)
                        else
                            NID(0x00000000000002ac)
                        end
                    else
                        nothing
                    end
                end
            end
        #= none:83 =#
        action !== nothing && return (action, m[NID(0x0000000000000442)], m[NID(0x0000000000000237)])
        #= none:84 =#
    end
    #= none:85 =#
    (NID(0x0000000000000322), nothing, nothing)
end
function scenario(spec)
    #= none:87 =#
    #= none:88 =#
    w = world(spec.hearing)
    #= none:88 =#
    states = D((a => nothing for a = IDS))
    #= none:89 =#
    pressure = pressure_update(nothing, D(), NID(0x00000000000004cb), 3)
    #= none:89 =#
    rows = Any[]
    #= none:89 =#
    nights = Any[]
    #= none:90 =#
    for day = 0:2
        #= none:91 =#
        b = w.bodies[NID(0x00000000000004cb)]
        #= none:91 =#
        w.bodies[NID(0x00000000000004cb)] = Body(b.burst, b.strain, max(0.0, b.reserve - 20), b.damage)
        #= none:92 =#
        for attempt = 0:1
            #= none:93 =#
            now = day * DAY + attempt * 6000000
            #= none:93 =#
            w.seconds = now / 1.0e6
            #= none:94 =#
            obs = observe(w, NID(0x00000000000004cb))
            #= none:94 =#
            s = if states[NID(0x00000000000004cb)] === nothing
                    social_initial()
                else
                    states[NID(0x00000000000004cb)]
                end
            #= none:95 =#
            targets = [o[NID(0x0000000000000195)] for o = obs[NID(0x00000000000002f4)] if o[NID(0x00000000000002f3)]]
            #= none:96 =#
            (target, selection) = select_target(targets, s[NID(0x000000000000008d)], pressure)
            #= none:97 =#
            row = D(NID(0x0000000000000173) => day, NID(0x00000000000004e9) => attempt, NID(0x00000000000004d4) => selection)
            #= none:98 =#
            if target === nothing
                #= none:99 =#
                push!(rows, row)
                #= none:99 =#
                continue
            end
            #= none:101 =#
            op = ncat(NID(0x00000000000002f5), day, NID(0x00000000000000da), attempt)
            #= none:101 =#
            mid = NID(0x0000000000000519) * op
            #= none:102 =#
            r = communicate!(w, NID(0x00000000000004cb), op, NID(0x00000000000002e8), target)
            #= none:103 =#
            #= none:103 =# @assert communicate!(w, NID(0x00000000000004cb), op, NID(0x00000000000002e8), target) == r
            #= none:104 =#
            s = deepcopy(s)
            #= none:104 =#
            s[NID(0x0000000000000145)] = D(NID(0x00000000000002f6) => mid, NID(0x00000000000001b0) => target, NID(0x00000000000002f7) => now + 5000000, NID(0x00000000000002f8) => ncat(NID(0x00000000000002d0), day, NID(0x00000000000000da), attempt), NID(0x00000000000002f9) => op)
            #= none:106 =#
            w.seconds = (now + 1000000) / 1.0e6
            #= none:107 =#
            decision = response(observe(w, target), target != NID(0x00000000000002ee))
            #= none:108 =#
            reply = communicate!(w, target, ncat(NID(0x000000000000051a), day, NID(0x00000000000000da), attempt), decision...)
            #= none:109 =#
            capture = now + if decision[1] != NID(0x0000000000000322)
                        2000000
                    else
                        5000000
                    end
            #= none:109 =#
            w.seconds = capture / 1.0e6
            #= none:110 =#
            p = D(NID(0x00000000000002cd) => NID(0x00000000000004cb), NID(0x00000000000002ce) => capture, NID(0x00000000000002cf) => ncat(NID(0x000000000000051b), day, NID(0x00000000000000da), attempt), NID(0x00000000000002d1) => observe(w, NID(0x00000000000004cb)))
            #= none:111 =#
            s = ingest(s, p, D(op => r))
            #= none:111 =#
            pressure = pressure_update(pressure, s[NID(0x000000000000028a)], NID(0x00000000000004cb), 3)
            #= none:112 =#
            states[NID(0x00000000000004cb)] = s
            #= none:113 =#
            w.inventory[NID(0x00000000000004cb)] > 0 && communicate!(w, NID(0x00000000000004cb), ncat(NID(0x000000000000051c), day, NID(0x00000000000000da), attempt), NID(0x00000000000002f0))
            #= none:114 =#
            merge!(row, D(NID(0x00000000000002e8) => r, NID(0x00000000000001d2) => reply, NID(0x00000000000001ce) => deepcopy(s), NID(0x000000000000042d) => deepcopy(pressure), NID(0x0000000000000081) => copy(w.inventory)))
            #= none:115 =#
            push!(rows, row)
            #= none:116 =#
        end
        #= none:117 =#
        start = day * DAY + 14400000000
        #= none:117 =#
        night = D()
        #= none:118 =#
        for actor = IDS
            #= none:119 =#
            learning = sleeper(day)
            #= none:120 =#
            for sec = 0:spec.rest_seconds - 1
                #= none:121 =#
                phase = if spec.interrupt && sec == 100
                        NID(0x000000000000007b)
                    else
                        NID(0x00000000000002d6)
                    end
                #= none:122 =#
                (w.bodies[actor], _, _, _) = step(w.bodies[actor], NID(0x00000000000002f2), w.inventory[actor])
                #= none:123 =#
                receipt!(learning, start + sec * 1000000; phase = phase)
                #= none:124 =#
                #= none:124 =# @assert !(receipt!(learning, start + sec * 1000000; phase = phase))
                #= none:125 =#
            end
            #= none:126 =#
            cycle = (learning[NID(0x0000000000000088)])[NID(0x0000000000000089)]
            #= none:127 =#
            states[actor] === nothing && (states[actor] = social_initial())
            #= none:128 =#
            if spec.adopt
                #= none:129 =#
                binding = merge(copy(cycle), D(NID(0x000000000000032f) => start))
                #= none:130 =#
                states[actor] = consolidate_social(states[actor], binding, actor)
                #= none:131 =#
                #= none:131 =# @assert consolidate_social(states[actor], binding, actor) == states[actor]
            end
            #= none:133 =#
            night[actor] = D(NID(0x0000000000000088) => learning[NID(0x0000000000000088)], NID(0x00000000000002d1) => deepcopy(states[actor]))
            #= none:134 =#
        end
        #= none:135 =#
        push!(nights, night)
        #= none:135 =#
        #= none:135 =# @assert sum(values(w.inventory)) + w.consumed == 24
        #= none:136 =#
    end
    #= none:137 =#
    D(NID(0x000000000000030e) => rows, NID(0x00000000000004ba) => nights, NID(0x0000000000000127) => states, NID(0x000000000000042d) => pressure, NID(0x0000000000000081) => w.inventory, NID(0x0000000000000149) => D((a => bodydict(w.bodies[a]) for a = IDS)), NID(0x0000000000000076) => w.consumed)
end
function boundaries()
    #= none:141 =#
    #= none:142 =#
    out = D()
    #= none:142 =#
    s = ginitial(NID(0x0000000000000049))
    #= none:142 =#
    snapshots = Any[]
    #= none:143 =#
    for (i, (confirmed, comparable)) = enumerate(((false, true), (false, false), (false, true), (true, true)))
        #= none:144 =#
        id = ncat(i - 1)
        #= none:144 =#
        s = gfinish(gbegin(s, id, D(NID(0x00000000000002cf) => id)), id, confirmed, comparable, NID(0x000000000000051d) * id)
        #= none:145 =#
        #= none:145 =# @assert gfinish(s, id, confirmed, comparable, NID(0x000000000000051d) * id) == s
        #= none:146 =#
        push!(snapshots, deepcopy(s))
        #= none:147 =#
    end
    #= none:148 =#
    out[NID(0x000000000000051e)] = snapshots
    #= none:148 =#
    errors = D()
    #= none:149 =#
    cases = D(NID(0x00000000000004e0) => (()->begin
                        #= none:149 =#
                        gfinish(s, NID(0x000000000000051f), false, true, NID(0x0000000000000520))
                    end), NID(0x0000000000000521) => (()->begin
                        #= none:149 =#
                        gbegin(s, NID(0x000000000000051f), D())
                    end), NID(0x000000000000013e) => (()->begin
                        #= none:150 =#
                        ginitial(NID(0x0000000000000049), NID(0x0000000000000522), NID(0x00000000000002e4), 0)
                    end), NID(0x0000000000000523) => (()->begin
                        #= none:151 =#
                        ginitial(NID(0x0000000000000049), NID(0x0000000000000522), NID(0x00000000000002e4), true)
                    end), NID(0x00000000000000f5) => (()->begin
                        #= none:152 =#
                        ginitial(NID(0x0000000000000049), NID(0x0000000000000522), NID(0x00000000000002e4), 2, NID(0x0000000000000049))
                    end), NID(0x0000000000000431) => (()->begin
                        #= none:153 =#
                        gfinish(s, NID(0x000000000000051f), 1, true, NID(0x0000000000000520))
                    end), NID(0x00000000000001bc) => (()->begin
                        #= none:154 =#
                        gbegin(gbegin(ginitial(NID(0x0000000000000049)), NID(0x00000000000000d1), D()), NID(0x0000000000000524), D())
                    end), NID(0x00000000000004ed) => (()->begin
                        #= none:155 =#
                        gfinish(ginitial(NID(0x0000000000000049)), NID(0x0000000000000498), false, true, NID(0x000000000000051d))
                    end))
    #= none:156 =#
    for (key, fn) = cases
        #= none:157 =#
        try
            #= none:157 =#
            fn()
            #= none:157 =#
            error(NID(0x0000000000000525))
        catch e
            #= none:157 =#
            errors[key] = e.msg
        end
        #= none:158 =#
        #= none:158 =# @assert errors[key] != NID(0x0000000000000525)
        #= none:159 =#
    end
    #= none:160 =#
    t = gbegin(ginitial(NID(0x0000000000000049)), NID(0x000000000000007b), D())
    #= none:160 =#
    (t[NID(0x00000000000001b6)])[NID(0x0000000000000526)] = true
    #= none:161 =#
    out[NID(0x0000000000000527)] = gfinish(t, NID(0x000000000000007b), false, true, NID(0x000000000000051d))
    #= none:161 =#
    out[NID(0x0000000000000088)] = D()
    #= none:162 =#
    start = 17278000000
    #= none:163 =#
    for name = (NID(0x000000000000024a), NID(0x000000000000007b), NID(0x0000000000000528), NID(0x000000000000018c), NID(0x0000000000000173))
        #= none:164 =#
        learning = sleeper(0, REST - 1000000)
        #= none:165 =#
        receipt!(learning, if name == NID(0x0000000000000173)
                DAY
            else
                start
            end; phase = if name == NID(0x000000000000007b)
                    NID(0x000000000000007b)
                else
                    NID(0x00000000000002d6)
                end, status = if name == NID(0x0000000000000528)
                    NID(0x000000000000036c)
                else
                    NID(0x0000000000000331)
                end, pose = name != NID(0x000000000000018c))
        #= none:167 =#
        (out[NID(0x0000000000000088)])[name] = learning
        #= none:168 =#
    end
    #= none:169 =#
    try
        #= none:169 =#
        receipt!(sleeper(0), start; accepted = false)
    catch e
        #= none:169 =#
        errors[NID(0x0000000000000529)] = e.msg
    end
    #= none:170 =#
    state = social_initial()
    #= none:171 =#
    for (i, (t, o)) = enumerate(((1, NID(0x0000000000000518)), (2, NID(0x00000000000002ac)), (9, NID(0x0000000000000518)), (1, NID(0x000000000000052a))))
        #= none:172 =#
        id = ncat(i - 1)
        #= none:172 =#
        (state[NID(0x000000000000028a)])[id] = D(NID(0x00000000000002cd) => NID(0x0000000000000049), NID(0x00000000000001b0) => NID(0x0000000000000255), NID(0x00000000000002f6) => id, NID(0x00000000000004c0) => t, NID(0x0000000000000336) => o)
        #= none:173 =#
    end
    #= none:174 =#
    before = deepcopy(state)
    #= none:174 =#
    cycle = D(NID(0x000000000000008a) => NID(0x0000000000000162), NID(0x0000000000000173) => 0, NID(0x000000000000032f) => 2)
    #= none:175 =#
    out[NID(0x000000000000052b)] = consolidate_social(state, cycle, NID(0x0000000000000049))
    #= none:175 =#
    #= none:175 =# @assert state == before
    #= none:176 =#
    try
        #= none:176 =#
        consolidate_social(state, cycle, NID(0x0000000000000430))
    catch e
        #= none:176 =#
        errors[NID(0x000000000000052c)] = e.msg
    end
    #= none:177 =#
    pending = social_initial()
    #= none:177 =#
    pending[NID(0x0000000000000145)] = D(NID(0x00000000000002f6) => NID(0x00000000000001bd), NID(0x00000000000001b0) => NID(0x0000000000000255), NID(0x00000000000002f7) => 5, NID(0x00000000000002f9) => NID(0x000000000000018d))
    #= none:178 =#
    p = D(NID(0x00000000000002ce) => 5, NID(0x00000000000002cd) => NID(0x0000000000000049), NID(0x00000000000002cf) => NID(0x000000000000051d), NID(0x00000000000002d1) => D(NID(0x00000000000001c3) => Any[]))
    #= none:179 =#
    out[NID(0x000000000000030a)] = ingest(pending, p, D())
    #= none:179 =#
    #= none:179 =# @assert pending[NID(0x0000000000000145)] !== nothing
    #= none:180 =#
    out[NID(0x00000000000004f4)] = errors
    #= none:180 =#
    out
end
nothing
