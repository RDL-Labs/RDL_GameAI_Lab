# CPU migration boundary. Numeric slots are stable in IDS order.
struct AgentSlots{T} <: AbstractDict{String,T}
    labels::Vector{String}
    index::Dict{String,Int32}
    data::Vector{T}
end
function AgentSlots(source::AbstractDict{String,T}) where T
    labels=collect(IDS)
    AgentSlots{T}(labels,Dict(a=>Int32(i) for (i,a) in enumerate(labels)),T[source[a] for a in labels])
end
Base.length(s::AgentSlots)=length(s.data)
Base.getindex(s::AgentSlots,a::AbstractString)=s.data[s.index[a]]
Base.getindex(s::AgentSlots,i::Integer)=s.data[i]
Base.setindex!(s::AgentSlots,v,a::AbstractString)=(s.data[s.index[a]]=v)
Base.setindex!(s::AgentSlots,v,i::Integer)=(s.data[i]=v)
Base.haskey(s::AgentSlots,a)=haskey(s.index,a)
Base.iterate(s::AgentSlots,i=1)=i>length(s) ? nothing : (s.labels[i]=>s.data[i],i+1)
Base.copy(s::AgentSlots)=AgentSlots(copy(Dict(s)))

# Explicit action ABI; never derive persistent IDs from hash() or encounter order.
const ACTION_LABELS=("wait","withdraw","eat","request","give","refuse","reach","warn",
    "rest","retrieve","pickup","walk","run","climb","drop","store","turn","scan","deposit","recover")
const ACTION_CODES=Dict(a=>UInt16(i) for (i,a) in enumerate(ACTION_LABELS))
struct NumericPlans
    actions::Vector{UInt16}
    payloads::Vector{D}
    index::Dict{String,Int32}
end
NumericPlans()=NumericPlans(zeros(UInt16,length(IDS)),[D() for _ in IDS],Dict(a=>Int32(i) for (i,a) in enumerate(IDS)))
function Base.setindex!(p::NumericPlans,plan,a::String)
    i=p.index[a]
    code=ACTION_CODES[plan["action"]] # Unknown actions fail visibly.
    payload=copy(plan)
    delete!(payload,"action")
    p.actions[i]=code
    p.payloads[i]=payload
    plan
end
function Base.getindex(p::NumericPlans,a::String)
    i=p.index[a]
    p.actions[i]!=0 || throw(KeyError(a))
    plan=copy(p.payloads[i])
    plan["action"]=ACTION_LABELS[p.actions[i]]
    plan
end

