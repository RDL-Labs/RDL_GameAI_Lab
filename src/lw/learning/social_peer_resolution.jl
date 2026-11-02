# Resolve a few currently observed peers in detail before expensive MB valuation.
# This is a computational attention approximation, not loss of peer memories.
function social_peer_scope!(relation,partners,loop,need,now)
    peers=unique(String.(partners))
    relation===nothing && return peers
    get(relation,"peer_rho_enabled",false) || return peers
    isempty(peers) && return peers
    signal=0.
    view=get(relation,"social_view",nothing)
    faces=Dict{String,Float64}()
    if view!==nothing
        for p in view["peers"]
            p["ref"] in peers || continue
            face=p["expression"];face===nothing && continue
            faces[p["ref"]]=max(face.distress,face.fear)
            signal=max(signal,faces[p["ref"]])
        end
    end
    # rho is the degree of individual differentiation. H/need are inputs to
    # its controller, not alternate names for rho. Quadratic onset suppresses
    # overreaction to small H; serious unresolved differences widen attention.
    pressure=max(clamp(Float64(need)/4,0.,1.),signal)
    rho=1-exp(-(max(0.,loop.H)/8)^2-4pressure^2)
    budget=min(length(peers),2+round(Int,max(0,length(peers)-2)*rho))
    selected=peers
    if budget<length(peers)
        scores=Float64[]
        for other in peers
            p=get(relation["peers"],other,nothing)
            contact=p===nothing ? 0. : p["contact_seconds"]
            samples=p===nothing ? 0 : p["trade_value_samples"]
            received=p===nothing ? 0 : p["aid_received"]["given"]
            # Cheap observed summaries only; no full social_mb_predict per peer.
            # Familiarity is not guaranteed benefit, so it biases attention only.
            weight=.25+contact/(60+contact)+samples/(2+samples)+received/(2+received)+get(faces,other,0.)
            push!(scores,-log(max(rand(loop.rng),eps(Float64)))/weight)
        end
        indices=sort!(sortperm(scores)[1:budget]) # keep original candidate order
        selected=peers[indices]
    end
    stats=get!(relation,"peer_resolution") do
        D("calls"=>0,"available"=>0,"detailed"=>0,"deferred"=>0,"records"=>Any[])
    end
    stats["calls"]+=1;stats["available"]+=length(peers)
    stats["detailed"]+=length(selected);stats["deferred"]+=length(peers)-length(selected)
    record=D("us"=>now,"goal"=>loop.goal,"rho"=>rho,"H"=>loop.H,"need"=>need,
        "available"=>length(peers),"selected"=>copy(selected),"coarse_group_count"=>length(peers)-length(selected))
    push!(stats["records"],record);length(stats["records"])>64 && popfirst!(stats["records"])
    selected
end
