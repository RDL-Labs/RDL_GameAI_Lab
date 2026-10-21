module MemoryBlocks
export AbstractBlock, LeafBlock, ParentBlock, execute

abstract type AbstractBlock end

"A reusable operation: numeric identity, applicability, estimated cost, and execution."
struct LeafBlock{P,C,F} <: AbstractBlock
    id::UInt32
    applicable::P
    cost::C
    apply::F
end

"Choose among child blocks; parents can themselves be children."
struct ParentBlock <: AbstractBlock
    id::UInt32
    children::Vector{AbstractBlock}
end
ParentBlock(id,children)=ParentBlock(UInt32(id),AbstractBlock[children...])

function candidate(b::LeafBlock,input,depth,tracking)
    depth>0 || throw(ArgumentError("MB depth limit"))
    b.applicable(input) || return nothing
    cost=Float64(b.cost(input))
    isfinite(cost) && cost>=0 || throw(ArgumentError("MB cost must be finite and nonnegative"))
    (leaf=b,cost=cost,path=tracking ? UInt32[b.id] : nothing)
end
function candidate(b::ParentBlock,input,depth,tracking)
    depth>0 || throw(ArgumentError("MB depth limit"))
    best=nothing
    for child in b.children
        next=candidate(child,input,depth-1,tracking)
        next===nothing && continue
        if best===nothing || next.cost<best.cost
            best=next
        end
    end
    best===nothing ? nothing : (leaf=best.leaf,cost=best.cost,path=tracking ? vcat(b.id,best.path) : nothing)
end

"Select without side effects, then execute exactly one leaf. Tracking affects output only."
function execute(block::AbstractBlock,input;tracking=true,maxdepth=32)
    chosen=candidate(block,input,maxdepth,tracking)
    chosen===nothing && return (status=:unavailable,output=input,cost=0.,path=UInt32[])
    output=chosen.leaf.apply(input)
    (status=:performed,output=output,cost=chosen.cost,path=tracking ? chosen.path : UInt32[])
end
end
