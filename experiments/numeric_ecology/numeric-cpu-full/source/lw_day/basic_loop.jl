# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
mutable struct MethodNode
    #= none:3 =#
    H::Int
    #= none:4 =#
    threshold::Int
    #= none:5 =#
    last_selected::Int
end
mutable struct BasicLoop
    #= none:8 =#
    goal::NID
    #= none:9 =#
    parent::Union{Nothing, NID}
    #= none:10 =#
    H::Int
    #= none:11 =#
    threshold::Int
    #= none:12 =#
    methods::Dict{NID, MethodNode}
    #= none:13 =#
    sequence::Int
    #= none:14 =#
    trial::Any
    #= none:15 =#
    receipt::Any
    #= none:16 =#
    events::Vector{Any}
end
BasicLoop(goal; parent = nothing, threshold = 2) = begin
        #= none:18 =#
        #= none:19 =#
        check(threshold > 0 && parent != goal, NID(0x00000000000005b6))
        #= none:20 =#
        BasicLoop(goal, parent, 0, threshold, Dict{NID, MethodNode}(), 0, nothing, nothing, Any[])
    end
#= none:24 =# Core.@doc("Finite parent-H admission before expensive fields; never invents feasible methods.", function parent_candidates(s::BasicLoop, candidates)
        #= none:25 =#
        #= none:27 =#
        level = if s.H >= 32
                2
            else
                min(2, fld(s.H, s.threshold))
            end
        #= none:28 =#
        limit = if level == 0
                2
            else
                if level == 1
                    4
                else
                    length(candidates)
                end
            end
        #= none:29 =#
        length(candidates) <= limit && return candidates
        #= none:30 =#
        uses = Dict{NID, Int}()
        #= none:31 =#
        for event = s.events
            #= none:32 =#
            uses[event.method] = get(uses, event.method, 0) + 1
            #= none:33 =#
        end
        #= none:35 =#
        key(c) = begin
                #= none:35 =#
                (-(get(uses, c[NID(0x00000000000001b7)], 0)), -(c[NID(0x00000000000002fc)]), c[NID(0x00000000000001b7)])
            end
        #= none:36 =#
        admitted = Any[]
        #= none:37 =#
        for c = candidates
            #= none:38 =#
            push!(admitted, c)
            #= none:39 =#
            sort!(admitted; by = key)
            #= none:40 =#
            length(admitted) > limit && pop!(admitted)
            #= none:41 =#
        end
        #= none:42 =#
        admitted
    end)
function method_choice(s::BasicLoop, candidates)
    #= none:45 =#
    #= none:46 =#
    isempty(candidates) && return nothing
    #= none:47 =#
    node(name) = begin
            #= none:47 =#
            get(s.methods, name, nothing)
        end
    #= none:50 =#
    reconsider = all((c->begin
                    #= none:50 =#
                    #= none:51 =#
                    n = node(c[NID(0x00000000000001b7)])
                    #= none:51 =#
                    n !== nothing && n.H >= n.threshold
                end), candidates)
    #= none:53 =#
    key(c) = begin
            #= none:53 =#
            #= none:54 =#
            n = node(c[NID(0x00000000000001b7)])
            #= none:55 =#
            h = if n === nothing
                    0
                else
                    n.H
                end
            #= none:55 =#
            t = if n === nothing
                    s.threshold
                else
                    n.threshold
                end
            #= none:56 =#
            last = if n === nothing
                    0
                else
                    n.last_selected
                end
            #= none:57 =#
            if reconsider
                (Float64(last), -(c[NID(0x00000000000002fc)]), c[NID(0x00000000000001b7)])
            else
                (-(c[NID(0x00000000000002fc)]) + min(2.0, h / t), Float64(last), c[NID(0x00000000000001b7)])
            end
        end
    #= none:60 =#
    selected = first(candidates)
    #= none:60 =#
    best = key(selected)
    #= none:61 =#
    for c = Iterators.drop(candidates, 1)
        #= none:62 =#
        k = key(c)
        #= none:63 =#
        if isless(k, best)
            #= none:63 =#
            selected = c
            #= none:63 =#
            best = k
        end
        #= none:64 =#
    end
    #= none:65 =#
    selected
end
function choose_method!(s::BasicLoop, candidates, source)
    #= none:68 =#
    #= none:69 =#
    check(s.trial === nothing, NID(0x00000000000005b7))
    #= none:70 =#
    isempty(candidates) && return nothing
    #= none:71 =#
    names = [c[NID(0x00000000000001b7)] for c = candidates]
    #= none:72 =#
    check(length(names) == length(unique(names)), NID(0x00000000000005b8))
    #= none:73 =#
    check(all((isfinite(c[NID(0x00000000000002fc)]) for c = candidates)), NID(0x00000000000005b9))
    #= none:74 =#
    for name = names
        #= none:75 =#
        get!(s.methods, name) do
            #= none:76 =#
            MethodNode(0, s.threshold, 0)
        end
        #= none:78 =#
    end
    #= none:79 =#
    reconsider = all(((s.methods[name]).H >= (s.methods[name]).threshold for name = names))
    #= none:80 =#
    selected = method_choice(s, candidates)
    #= none:81 =#
    s.sequence += 1
    #= none:81 =#
    (s.methods[selected[NID(0x00000000000001b7)]]).last_selected = s.sequence
    #= none:82 =#
    s.trial = (source = source, method = selected[NID(0x00000000000001b7)], question = selected[NID(0x00000000000001b4)])
    #= none:83 =#
    out = copy(selected)
    #= none:83 =#
    out[NID(0x0000000000000336)] = if reconsider
            NID(0x00000000000005ba)
        else
            NID(0x00000000000005bb)
        end
    #= none:83 =#
    out
end
function resolve_method!(s::BasicLoop, source, method_value, goal_value; accepted = true)
    #= none:86 =#
    #= none:87 =#
    check(accepted, NID(0x00000000000005bc))
    #= none:88 =#
    check(all((v === nothing || v isa Bool for v = (method_value, goal_value))), NID(0x00000000000005bd))
    #= none:89 =#
    evidence = (source = source, method_value = method_value, goal_value = goal_value)
    #= none:90 =#
    if s.receipt !== nothing && s.receipt.source == source
        #= none:91 =#
        check(s.receipt == evidence, NID(0x00000000000005be))
        #= none:91 =#
        return false
    end
    #= none:93 =#
    check(s.trial !== nothing && s.trial.source == source, NID(0x00000000000005bf))
    #= none:94 =#
    n = s.methods[s.trial.method]
    #= none:94 =#
    before = n.H
    #= none:94 =#
    parent_before = s.H
    #= none:95 =#
    method_value !== nothing && (n.H = if method_value
                0
            else
                min(32, n.H + 1)
            end)
    #= none:96 =#
    goal_value !== nothing && (s.H = if goal_value
                0
            else
                min(32, s.H + 1)
            end)
    #= none:97 =#
    push!(s.events, (source = source, method = s.trial.method, question = s.trial.question, E = if method_value === nothing
                    nothing
                else
                    Int(!method_value)
                end, H_before = before, H_after = n.H, goal_E = if goal_value === nothing
                    nothing
                else
                    Int(!goal_value)
                end, goal_H_before = parent_before, goal_H_after = s.H))
    #= none:100 =#
    length(s.events) > 32 && popfirst!(s.events)
    #= none:101 =#
    s.receipt = evidence
    #= none:101 =#
    s.trial = nothing
    #= none:101 =#
    true
end
loop_snapshot(s::BasicLoop) = begin
        #= none:103 =#
        D(NID(0x00000000000001b9) => s.goal, NID(0x00000000000000f5) => s.parent, NID(0x00000000000001e8) => s.H, NID(0x000000000000013e) => s.threshold, NID(0x0000000000000407) => s.sequence, NID(0x00000000000001c2) => D((k => D(NID(0x00000000000001e8) => v.H, NID(0x000000000000013e) => v.threshold, NID(0x00000000000005a8) => v.last_selected) for (k, v) = s.methods)), NID(0x000000000000012f) => copy(s.events))
    end
function search_candidates(move, target, loop)
    #= none:107 =#
    #= none:108 =#
    candidates = Any[D(NID(0x00000000000001b7) => NID(0x000000000000038b), NID(0x000000000000021f) => NID(0x0000000000000309), NID(0x00000000000002fc) => 2.0, NID(0x00000000000001b4) => NID(0x00000000000002e3))]
    #= none:110 =#
    if target !== nothing || loop.H >= loop.threshold
        #= none:111 =#
        for row = (move[NID(0x000000000000030b)])[NID(0x000000000000030c)]
            #= none:112 =#
            row[NID(0x000000000000030a)] === nothing && continue
            #= none:113 =#
            index = parse(Int, row[NID(0x0000000000000195)])
            #= none:113 =#
            angle = deg2rad(Float64(ANGLES[index + 1]))
            #= none:114 =#
            alignment = if target === nothing
                    0.0
                else
                    cos(atan(target[NID(0x000000000000027a)], target[NID(0x0000000000000279)]) - angle)
                end
            #= none:115 =#
            push!(candidates, D(NID(0x00000000000001b7) => ncat(NID(0x00000000000005c0), ANGLES[index + 1]), NID(0x000000000000021f) => NID(0x000000000000030d), NID(0x0000000000000251) => index, NID(0x00000000000002fc) => if target === nothing
                            1.5
                        else
                            3.0 + alignment
                        end, NID(0x00000000000001b4) => if target === nothing
                            NID(0x00000000000002e3)
                        else
                            NID(0x0000000000000420)
                        end))
            #= none:118 =#
        end
    end
    #= none:120 =#
    candidates
end
