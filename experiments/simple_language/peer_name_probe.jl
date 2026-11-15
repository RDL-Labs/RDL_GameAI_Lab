# Local initial knowledge only; separate owner-held name relations from world IDs.
# Names are not inferred from actor identifiers, and do not prove caller identity.
mutable struct LocalPeerNames
 owner::String
 relations::Dict{String,Vector{String}}
end
LocalPeerNames(owner)=LocalPeerNames(owner,Dict{String,Vector{String}}())
function seed_peer_name!(names,peer,name)
 isempty(strip(name)) && error("empty peer name")
 entries=get!(()->String[],names.relations,peer)
 name in entries || push!(entries,name)
 names
end
function recall_peer_name(names,listener,visual_result)
 names.owner==listener || error("name memory owner mismatch")
 visual_result.peer===nothing && return (status=:unidentified,names=String[],reply=nothing)
 candidates=copy(get(names.relations,visual_result.peer,String[]))
 isempty(candidates) && return (status=:unknown_name,names=candidates,reply=nothing)
 length(candidates)==1 || return (status=:multiple_names,names=candidates,reply=nothing)
 (status=:recalled,names=candidates,reply=only(candidates)*"？")
end
