# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
const D = Dict{NID, Any}
mutable struct Records <: AbstractDict{NID, Any}
    #= none:4 =#
    data::D
    #= none:5 =#
    order::Vector{NID}
end
Records() = begin
        #= none:7 =#
        Records(D(), NID[])
    end
Base.length(r::Records) = begin
        #= none:8 =#
        length(r.order)
    end
Base.iterate(r::Records, i = 1) = begin
        #= none:9 =#
        if i > length(r.order)
            nothing
        else
            (r.order[i] => r.data[r.order[i]], i + 1)
        end
    end
Base.getindex(r::Records, k) = begin
        #= none:10 =#
        r.data[k]
    end
Base.get(r::Records, k, default) = begin
        #= none:11 =#
        get(r.data, k, default)
    end
Base.haskey(r::Records, k) = begin
        #= none:12 =#
        haskey(r.data, k)
    end
Base.keys(r::Records) = begin
        #= none:13 =#
        r.order
    end
function Base.setindex!(r::Records, v, k)
    #= none:14 =#
    #= none:15 =#
    haskey(r, k) || push!(r.order, k)
    #= none:16 =#
    r.data[k] = v
end
check(c, code) = begin
        #= none:18 =#
        c || error(code)
    end
abstract type LocalModelState <: AbstractDict{NID, Any} end
mutable struct GoalState <: LocalModelState
    #= none:24 =#
    goal_id::NID
    #= none:25 =#
    model_ref::NID
    #= none:26 =#
    dimension::NID
    #= none:27 =#
    parent_goal_id::Any
    #= none:28 =#
    H::Int
    #= none:29 =#
    threshold::Int
    #= none:30 =#
    records::Records
    #= none:31 =#
    trial::Union{Nothing, D}
end
mutable struct AidPressure <: LocalModelState
    #= none:34 =#
    parent::GoalState
    #= none:35 =#
    methods::Dict{NID, GoalState}
end
Base.length(s::LocalModelState) = begin
        #= none:37 =#
        fieldcount(typeof(s))
    end
Base.keys(s::LocalModelState) = begin
        #= none:38 =#
        NID.(fieldnames(typeof(s)))
    end
Base.haskey(s::LocalModelState, k) = begin
        #= none:39 =#
        k isa NID && Symbol(k) in fieldnames(typeof(s))
    end
Base.getindex(s::LocalModelState, k) = begin
        #= none:40 =#
        if haskey(s, k)
            getfield(s, Symbol(k))
        else
            throw(KeyError(k))
        end
    end
Base.get(s::LocalModelState, k, default) = begin
        #= none:41 =#
        if haskey(s, k)
            s[k]
        else
            default
        end
    end
function Base.iterate(s::LocalModelState, i = 1)
    #= none:42 =#
    #= none:43 =#
    i > length(s) && return nothing
    #= none:44 =#
    (NID(fieldname(typeof(s), i)) => getfield(s, i), i + 1)
end
function ginitial(id, model = NID(0x0000000000000522), dim = NID(0x00000000000002e4), theta = 2, parent = nothing)
    #= none:47 =#
    #= none:48 =#
    check(all((x->begin
                    #= none:48 =#
                    x isa NID && !(isempty(x))
                end), (id, model, dim)), NID(0x000000000000056b))
    #= none:49 =#
    check(theta isa Int && (!(theta isa Bool) && theta >= 1), NID(0x000000000000056c))
    #= none:50 =#
    check(parent != id, NID(0x000000000000056d))
    #= none:51 =#
    GoalState(id, model, dim, parent, 0, theta, Records(), nothing)
end
gmethod(s, enabled, primary, alternative) = begin
        #= none:53 =#
        if enabled && s.H >= s.threshold
            alternative
        else
            primary
        end
    end
function gbegin(state, id, source)
    #= none:54 =#
    #= none:55 =#
    s = deepcopy(state)
    #= none:56 =#
    trial = D(NID(0x000000000000056e) => id, NID(0x0000000000000121) => deepcopy(source), NID(0x000000000000008c) => s.model_ref, NID(0x000000000000042f) => s.goal_id, NID(0x000000000000055d) => s.dimension, NID(0x000000000000056f) => D(s.dimension => 1))
    #= none:58 =#
    if s.trial !== nothing
        #= none:59 =#
        check(s.trial == trial, NID(0x0000000000000570))
        #= none:59 =#
        return s
    end
    #= none:61 =#
    check(!(haskey(s.records, id)), NID(0x0000000000000571))
    #= none:61 =#
    s.trial = trial
    #= none:61 =#
    s
end
function gfinish(state, id, confirmed, comparable, source)
    #= none:63 =#
    #= none:64 =#
    check(confirmed isa Bool && comparable isa Bool, NID(0x0000000000000572))
    #= none:65 =#
    s = deepcopy(state)
    #= none:66 =#
    compared = if haskey(state.records, id)
            (state.records[id])[NID(0x00000000000001b6)]
        else
            state.trial
        end
    #= none:67 =#
    if compared !== nothing && (get(compared, NID(0x0000000000000526), false) && !confirmed)
        #= none:68 =#
        comparable = false
    end
    #= none:70 =#
    evidence = D(NID(0x00000000000004f1) => confirmed, NID(0x000000000000022a) => comparable, NID(0x0000000000000121) => source)
    #= none:71 =#
    if haskey(s.records, id)
        #= none:72 =#
        check((s.records[id])[NID(0x0000000000000431)] == evidence, NID(0x0000000000000573))
        #= none:72 =#
        return s
    end
    #= none:74 =#
    trial = s.trial
    #= none:74 =#
    check(trial !== nothing && trial[NID(0x000000000000056e)] == id, NID(0x0000000000000574))
    #= none:75 =#
    E = if comparable
            if confirmed
                0
            else
                1
            end
        else
            nothing
        end
    #= none:75 =#
    before = s.H
    #= none:76 =#
    comparable && (s.H = if confirmed
                0
            else
                before + E
            end)
    #= none:77 =#
    s.records[id] = D(NID(0x00000000000001b6) => deepcopy(trial), NID(0x0000000000000431) => evidence, NID(0x0000000000000575) => if comparable
                    D(trial[NID(0x000000000000055d)] => Int(confirmed))
                else
                    nothing
                end, NID(0x0000000000000444) => E, NID(0x000000000000045f) => before, NID(0x0000000000000447) => s.H, NID(0x000000000000008a) => if comparable
                    NID(0x000000000000049f)
                else
                    NID(0x0000000000000576)
                end)
    #= none:80 =#
    s.trial = nothing
    #= none:80 =#
    s
end
function pressure_update(previous, records, actor, theta = 2)
    #= none:82 =#
    #= none:83 =#
    s = if previous === nothing
            AidPressure(ginitial(actor * NID(0x0000000000000440), NID(0x0000000000000577), NID(0x0000000000000578), theta), Dict{NID, GoalState}())
        else
            deepcopy(previous)
        end
    #= none:84 =#
    check(s.parent.goal_id == actor * NID(0x0000000000000440), NID(0x0000000000000579))
    #= none:85 =#
    for (id, r) = records
        #= none:86 =#
        check(r[NID(0x00000000000002cd)] == actor, NID(0x000000000000057a))
        #= none:87 =#
        haskey(s.parent.records, id) && continue
        #= none:88 =#
        target = r[NID(0x00000000000001b0)]
        #= none:89 =#
        if !(haskey(s.methods, target))
            #= none:90 =#
            s.methods[target] = ginitial(actor * NID(0x000000000000057b) * target, NID(0x0000000000000577), NID(0x0000000000000578), theta, s.parent.goal_id)
        end
        #= none:92 =#
        source = D(NID(0x00000000000002cf) => r[NID(0x00000000000002f8)])
        #= none:93 =#
        confirmed = r[NID(0x0000000000000336)] == NID(0x0000000000000518)
        #= none:93 =#
        comparable = r[NID(0x0000000000000336)] != NID(0x000000000000052a)
        #= none:94 =#
        s.parent = gfinish(gbegin(s.parent, id, source), id, confirmed, comparable, r[NID(0x0000000000000445)])
        #= none:95 =#
        s.methods[target] = gfinish(gbegin(s.methods[target], id, source), id, confirmed, comparable, r[NID(0x0000000000000445)])
        #= none:96 =#
    end
    #= none:97 =#
    s
end
function select_target(targets, model, pressure)
    #= none:99 =#
    #= none:100 =#
    candidates = Any[]
    #= none:101 =#
    for target = sort(unique(targets))
        #= none:102 =#
        state = get(pressure.methods, target, nothing)
        #= none:103 =#
        H = if state === nothing
                0
            else
                state.H
            end
        #= none:104 =#
        theta = if state === nothing
                pressure.parent.threshold
            else
                state.threshold
            end
        #= none:105 =#
        penalty = if H >= theta
                min(2, H / theta)
            else
                0
            end
        #= none:106 =#
        push!(candidates, D(NID(0x00000000000001b0) => target, NID(0x00000000000001e8) => H, NID(0x000000000000013e) => theta, NID(0x000000000000034c) => get(get(model, target, D()), NID(0x000000000000057c), 0.5) - penalty))
        #= none:108 =#
    end
    #= none:109 =#
    if pressure.parent.H >= pressure.parent.threshold
        #= none:110 =#
        push!(candidates, D(NID(0x00000000000001b0) => nothing, NID(0x000000000000034c) => 0.25, NID(0x0000000000000366) => NID(0x000000000000057d)))
    end
    #= none:112 =#
    chosen = if isempty(candidates)
            nothing
        else
            candidates[argmin([(-(c[NID(0x000000000000034c)]), if c[NID(0x00000000000001b0)] === nothing
                            NID(0x0000000000000334)
                        else
                            c[NID(0x00000000000001b0)]
                        end) for c = candidates])]
        end
    #= none:113 =#
    (if chosen === nothing
            nothing
        else
            chosen[NID(0x00000000000001b0)]
        end, D(NID(0x00000000000001e2) => candidates, NID(0x0000000000000304) => deepcopy(chosen)))
end
social_initial() = begin
        #= none:115 =#
        D(NID(0x000000000000028a) => Records(), NID(0x0000000000000145) => nothing, NID(0x000000000000008d) => D(), NID(0x0000000000000471) => Any[])
    end
function ingest(state, packet, results)
    #= none:116 =#
    #= none:117 =#
    s = if state === nothing
            social_initial()
        else
            deepcopy(state)
        end
    #= none:118 =#
    pending = s[NID(0x0000000000000145)]
    #= none:119 =#
    if pending !== nothing
        #= none:120 =#
        messages = [m for m = (packet[NID(0x00000000000002d1)])[NID(0x00000000000001c3)] if m[NID(0x00000000000002ef)] == pending[NID(0x00000000000002f6)] && (m[NID(0x0000000000000442)] == pending[NID(0x00000000000001b0)] && (m[NID(0x000000000000024d)] in (NID(0x0000000000000518), NID(0x00000000000002ac)) && m[NID(0x0000000000000164)] * 1.0e6 < pending[NID(0x00000000000002f7)]))]
        #= none:122 =#
        response = if isempty(messages)
                nothing
            else
                messages[1]
            end
        #= none:122 =#
        own = get(results, pending[NID(0x00000000000002f9)], nothing)
        #= none:123 =#
        if response !== nothing || packet[NID(0x00000000000002ce)] >= pending[NID(0x00000000000002f7)]
            #= none:124 =#
            check(length(s[NID(0x000000000000028a)]) < 192, NID(0x000000000000057e))
            #= none:125 =#
            r = deepcopy(pending)
            #= none:126 =#
            merge!(r, D(NID(0x00000000000002cd) => packet[NID(0x00000000000002cd)], NID(0x0000000000000336) => if own === nothing || own[NID(0x000000000000008a)] != NID(0x0000000000000517)
                            NID(0x000000000000052a)
                        else
                            if response === nothing
                                NID(0x000000000000057f)
                            else
                                response[NID(0x000000000000024d)]
                            end
                        end, NID(0x0000000000000445) => packet[NID(0x00000000000002cf)], NID(0x00000000000004c0) => packet[NID(0x00000000000002ce)], NID(0x0000000000000580) => NID(0x00000000000003df)))
            #= none:128 =#
            (s[NID(0x000000000000028a)])[pending[NID(0x00000000000002f6)]] = r
            #= none:128 =#
            s[NID(0x0000000000000145)] = nothing
        end
    end
    #= none:131 =#
    s
end
function consolidate_social(state, cycle, actor)
    #= none:133 =#
    #= none:134 =#
    s = deepcopy(state)
    #= none:135 =#
    (cycle === nothing || (cycle[NID(0x000000000000008a)] != NID(0x0000000000000162) || cycle[NID(0x0000000000000173)] in s[NID(0x0000000000000471)])) && return s
    #= none:136 =#
    records = collect(values(s[NID(0x000000000000028a)]))
    #= none:137 =#
    check(all((r->begin
                    #= none:137 =#
                    r[NID(0x00000000000002cd)] == actor
                end), records), NID(0x0000000000000581))
    #= none:138 =#
    records = [r for r = records if r[NID(0x00000000000004c0)] <= cycle[NID(0x000000000000032f)] && r[NID(0x0000000000000336)] != NID(0x000000000000052a)]
    #= none:139 =#
    for target = sort(unique([r[NID(0x00000000000001b0)] for r = records]))
        #= none:140 =#
        group = [r for r = records if r[NID(0x00000000000001b0)] == target]
        #= none:141 =#
        (s[NID(0x000000000000008d)])[target] = D(NID(0x000000000000057c) => (1 + count((r->begin
                                        #= none:141 =#
                                        r[NID(0x0000000000000336)] == NID(0x0000000000000518)
                                    end), group)) / (2 + length(group)), NID(0x0000000000000414) => [r[NID(0x00000000000002f6)] for r = group], NID(0x00000000000003f7) => NID(0x0000000000000582))
        #= none:143 =#
    end
    #= none:144 =#
    push!(s[NID(0x0000000000000471)], cycle[NID(0x0000000000000173)])
    #= none:144 =#
    s
end
const DAY = 17280000000
const REST = 2880000000
function sleeper(day, rest = 0)
    #= none:149 =#
    #= none:150 =#
    D(NID(0x0000000000000088) => D(NID(0x0000000000000089) => D(NID(0x0000000000000173) => day, NID(0x000000000000008a) => NID(0x0000000000000145), NID(0x000000000000032e) => rest, NID(0x000000000000028a) => Any[], NID(0x0000000000000121) => NID(0x00000000000002d6), NID(0x00000000000003fb) => nothing, NID(0x0000000000000583) => D(NID(0x000000000000028a) => Any[], NID(0x0000000000000584) => D()), NID(0x0000000000000585) => nothing), NID(0x0000000000000162) => Any[]))
end
function receipt!(learning, now; phase = NID(0x00000000000002d6), status = NID(0x0000000000000331), pose = true, kind = NID(0x0000000000000322), accepted = true, on_complete = nothing)
    #= none:153 =#
    #= none:154 =#
    check(accepted, NID(0x0000000000000586))
    #= none:155 =#
    c = (learning[NID(0x0000000000000088)])[NID(0x0000000000000089)]
    #= none:156 =#
    c[NID(0x000000000000008a)] != NID(0x0000000000000145) && return false
    #= none:157 =#
    executed = now + 1000000
    #= none:158 =#
    executed <= get(c, NID(0x0000000000000587), -1) && return false
    #= none:159 =#
    c[NID(0x0000000000000173)] != div(now, DAY) && return false
    #= none:160 =#
    valid = phase == NID(0x00000000000002d6) && (kind == NID(0x0000000000000322) && (status == NID(0x0000000000000331) && (pose && now < executed <= (c[NID(0x0000000000000173)] + 1) * DAY)))
    #= none:161 =#
    c[NID(0x0000000000000588)] = ncat(NID(0x00000000000002eb), now)
    #= none:161 =#
    c[NID(0x0000000000000587)] = executed
    #= none:162 =#
    c[NID(0x000000000000032e)] = if valid
            c[NID(0x000000000000032e)] + 1000000
        else
            0
        end
    #= none:163 =#
    if c[NID(0x000000000000032e)] >= REST
        #= none:164 =#
        if on_complete !== nothing
            #= none:165 =#
            on_complete(c, executed)
            #= none:166 =#
            c[NID(0x000000000000008a)] = NID(0x0000000000000162)
            #= none:166 =#
            c[NID(0x000000000000049d)] = executed
            #= none:167 =#
            return true
        end
        #= none:170 =#
        check(isempty(c[NID(0x000000000000028a)]) && isempty((c[NID(0x0000000000000583)])[NID(0x000000000000028a)]), NID(0x0000000000000589))
        #= none:171 =#
        c[NID(0x0000000000000585)] = D(NID(0x00000000000000c6) => NID(0x000000000000058a), NID(0x000000000000008a) => NID(0x000000000000049e), NID(0x0000000000000584) => D(), NID(0x000000000000028a) => Any[], NID(0x000000000000058b) => Any[], NID(0x000000000000058c) => Any[], NID(0x000000000000058d) => NID(0x0000000000000457), NID(0x00000000000003f7) => NID(0x000000000000058e))
        #= none:174 =#
        c[NID(0x000000000000008a)] = NID(0x0000000000000162)
        #= none:174 =#
        c[NID(0x00000000000003fb)] = D(NID(0x000000000000008a) => NID(0x000000000000058f), NID(0x0000000000000366) => nothing, NID(0x000000000000008c) => nothing)
        #= none:175 =#
        c[NID(0x000000000000049d)] = executed
    end
    #= none:177 =#
    true
end
