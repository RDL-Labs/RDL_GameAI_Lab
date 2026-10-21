# A1 GameAI-local parity. Not canonical E/H/T1.
const D=Dict{String,Any}
mutable struct Records <: AbstractDict{String,Any}
    data::D
    order::Vector{String}
end
Records()=Records(D(),String[])
Base.length(r::Records)=length(r.order)
Base.iterate(r::Records,i=1)=i>length(r.order) ? nothing : (r.order[i]=>r.data[r.order[i]],i+1)
Base.getindex(r::Records,k)=r.data[k]
Base.get(r::Records,k,default)=get(r.data,k,default)
Base.haskey(r::Records,k)=haskey(r.data,k)
Base.keys(r::Records)=r.order
function Base.setindex!(r::Records,v,k)
    haskey(r,k) || push!(r.order,k)
    r.data[k]=v
end
check(c,code)=c || error(code)

# Fixed state fields; open-ended evidence payloads remain owned dictionaries.
# AbstractDict is an output/compatibility view. Updates below use concrete fields.
abstract type LocalModelState <: AbstractDict{String,Any} end
mutable struct GoalState <: LocalModelState
    goal_id::String
    model_ref::String
    dimension::String
    parent_goal_id::Any # Existing API permits opaque parent references.
    H::Int
    threshold::Int
    records::Records
    trial::Union{Nothing,D}
end
mutable struct AidPressure <: LocalModelState
    parent::GoalState
    methods::Dict{String,GoalState}
end
Base.length(s::LocalModelState)=fieldcount(typeof(s))
Base.keys(s::LocalModelState)=String.(fieldnames(typeof(s)))
Base.haskey(s::LocalModelState,k)=k isa String && Symbol(k) in fieldnames(typeof(s))
Base.getindex(s::LocalModelState,k)=haskey(s,k) ? getfield(s,Symbol(k)) : throw(KeyError(k))
Base.get(s::LocalModelState,k,default)=haskey(s,k) ? s[k] : default
function Base.iterate(s::LocalModelState,i=1)
    i>length(s) && return nothing
    (String(fieldname(typeof(s),i))=>getfield(s,i),i+1)
end
