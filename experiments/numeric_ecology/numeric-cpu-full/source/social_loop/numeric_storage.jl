# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
struct AgentSlots{T} <: AbstractDict{NID, T}
    #= none:3 =#
    labels::Vector{NID}
    #= none:4 =#
    index::Dict{NID, Int32}
    #= none:5 =#
    data::Vector{T}
end
function AgentSlots(source::AbstractDict{NID, T}) where T
    #= none:7 =#
    #= none:8 =#
    labels = collect(IDS)
    #= none:9 =#
    AgentSlots{T}(labels, Dict((a => Int32(i) for (i, a) = enumerate(labels))), T[source[a] for a = labels])
end
Base.length(s::AgentSlots) = begin
        #= none:11 =#
        length(s.data)
    end
Base.getindex(s::AgentSlots, a::NID) = begin
        #= none:12 =#
        s.data[s.index[a]]
    end
Base.getindex(s::AgentSlots, i::Integer) = begin
        #= none:13 =#
        s.data[i]
    end
Base.setindex!(s::AgentSlots, v, a::NID) = begin
        #= none:14 =#
        s.data[s.index[a]] = v
    end
Base.setindex!(s::AgentSlots, v, i::Integer) = begin
        #= none:15 =#
        s.data[i] = v
    end
Base.haskey(s::AgentSlots, a) = begin
        #= none:16 =#
        haskey(s.index, a)
    end
Base.iterate(s::AgentSlots, i = 1) = begin
        #= none:17 =#
        if i > length(s)
            nothing
        else
            (s.labels[i] => s.data[i], i + 1)
        end
    end
Base.copy(s::AgentSlots) = begin
        #= none:18 =#
        AgentSlots(copy(Dict(s)))
    end
const ACTION_LABELS = (NID(0x0000000000000320), NID(0x000000000000031f), NID(0x00000000000002ee), NID(0x00000000000002e6), NID(0x00000000000002a9), NID(0x00000000000002aa), NID(0x00000000000002e8), NID(0x00000000000002e7), NID(0x00000000000002f0), NID(0x00000000000002ef), NID(0x00000000000002fa), NID(0x000000000000030d), NID(0x000000000000031a), NID(0x0000000000000315), NID(0x0000000000000323), NID(0x0000000000000598), NID(0x0000000000000363), NID(0x0000000000000309), NID(0x00000000000002f8), NID(0x00000000000002f9))
const ACTION_CODES = Dict((a => UInt16(i) for (i, a) = enumerate(ACTION_LABELS)))
struct NumericPlans
    #= none:25 =#
    actions::Vector{UInt16}
    #= none:26 =#
    payloads::Vector{D}
    #= none:27 =#
    index::Dict{NID, Int32}
end
NumericPlans() = begin
        #= none:29 =#
        NumericPlans(zeros(UInt16, length(IDS)), [D() for _ = IDS], Dict((a => Int32(i) for (i, a) = enumerate(IDS))))
    end
function Base.setindex!(p::NumericPlans, plan, a::NID)
    #= none:30 =#
    #= none:31 =#
    i = p.index[a]
    #= none:32 =#
    code = ACTION_CODES[plan[NID(0x000000000000021f)]]
    #= none:33 =#
    payload = copy(plan)
    #= none:34 =#
    delete!(payload, NID(0x000000000000021f))
    #= none:35 =#
    p.actions[i] = code
    #= none:36 =#
    p.payloads[i] = payload
    #= none:37 =#
    plan
end
function Base.getindex(p::NumericPlans, a::NID)
    #= none:39 =#
    #= none:40 =#
    i = p.index[a]
    #= none:41 =#
    p.actions[i] != 0 || throw(KeyError(a))
    #= none:42 =#
    plan = copy(p.payloads[i])
    #= none:43 =#
    plan[NID(0x000000000000021f)] = ACTION_LABELS[p.actions[i]]
    #= none:44 =#
    plan
end
