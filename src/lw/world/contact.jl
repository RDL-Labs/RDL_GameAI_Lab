mutable struct ContactWorld
    inventory::Dict{String,Int}
    bodies::Dict{String,Body}
    inbox::Dict{String,Vector{Any}}
    hearing::Dict{String,Bool}
    receipts::D
    answered::Set{Tuple{String,String}}
    seconds::Float64
    consumed::Int
    positions::Dict{String,Tuple{Float64,Float64}}
    obstacles::Vector{RDLMigrationProbe.Circle}
    capacity::Int
end
function world(hearing)
    ContactWorld(Dict(a=>(a=="npc_a" ? 0 : 12) for a in IDS),
        Dict(a=>Body(10.,0.,50.,0.) for a in IDS),Dict(a=>Any[] for a in IDS),
        Dict(a=>(a!="npc_b" || hearing) for a in IDS),D(),Set{Tuple{String,String}}(),0.,0,
        Dict(a=>((i-1)*.4,0.) for (i,a) in enumerate(IDS)),RDLMigrationProbe.Circle[],256)
end
function contact(w,a,b)
    b in IDS && b!=a || return false
    p,q=w.positions[a],w.positions[b]
    hypot(q[1]-p[1],q[2]-p[2])<=1.25 && !any(o->segment_hit(p,q,o,0.),w.obstacles)
end
