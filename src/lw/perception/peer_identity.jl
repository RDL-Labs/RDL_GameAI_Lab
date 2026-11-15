# Same provisional five-feature quantization as the local appearance probe.
const PEER_IDENTITY_RULES=(near=2.,middle=4.,front=45.,side=120.,minimum=3,records=32)
function peer_identity_patch(features,distance,angle,rho)
    length(features)==5 && all(x->isfinite(x) && 0<=x<=1,features) || error("identity features")
    bins=min(distance<=PEER_IDENTITY_RULES.near ? 8 : distance<=PEER_IDENTITY_RULES.middle ? 4 : 2,
        rho=="fine" ? 8 : rho=="medium" ? 4 : 2)
    a=abs(mod(angle+180,360)-180)
    mask=a<=PEER_IDENTITY_RULES.front ? (true,true,true,true,true) :
        a<=PEER_IDENTITY_RULES.side ? (false,true,true,true,false) : (false,false,true,false,false)
    (features=ntuple(i->mask[i] ? min(bins-1,floor(Int,features[i]*bins)) : nothing,5),bins=bins)
end
function peer_identity_match(memory,patch)
    candidates=sort!([String(peer) for (peer,features) in memory if all(i->patch.features[i]===nothing ||
        min(patch.bins-1,floor(Int,features[i]*patch.bins))==patch.features[i],1:5)])
    observed=count(!isnothing,patch.features)
    status=observed<PEER_IDENTITY_RULES.minimum ? "insufficient_observation" :
        isempty(candidates) ? "unknown" : length(candidates)>1 ? "ambiguous" : "recognized"
    (status=status,peer=status=="recognized" ? only(candidates) : nothing,candidates=candidates)
end

# World adapter reads geometry/appearance; matcher receives no world actor ID.
# Diagnostic connection only: legacy routing/learning is deliberately untouched.
function peer_identity_observe!(relation,sight,w,actor,yaw,roster,now)
    state=get!(()->configured_peer_identity_memory(actor,roster),relation,"identity_observation")
    rows=Any[]
    for silhouette in sight["peers"]
        physical= silhouette["ref"]
        p=w.positions[actor];q=w.positions[physical]
        angle=atand(p[1]-q[1],p[2]-q[2])-yaw[physical]
        # Coarse first; finer observation is a diagnostic sample, not a free action.
        samples=Any[];identity=nothing
        for rho in ("coarse","medium","fine")
            patch=peer_identity_patch(roster[physical]["features"],hypot(q[1]-p[1],q[2]-p[2]),angle,rho)
            identity=peer_identity_match(state["features"],patch)
            push!(samples,D("rho"=>rho,"bins"=>patch.bins,"features"=>collect(patch.features),"status"=>identity.status))
            identity.status=="recognized" && break
        end
        state["counts"][identity.status]=get(state["counts"],identity.status,0)+1
        recalled=identity.peer===nothing ? nothing : state["names"][identity.peer]
        bias=identity.peer===nothing ? nothing : social_relation_bias(relation,identity.peer,"give")
        push!(rows,D("bearing"=>silhouette["angle"],"status"=>identity.status,"inferred_peer"=>identity.peer,
            "name"=>recalled,"candidates"=>identity.candidates,"samples"=>samples,
            "relation_weight"=>bias===nothing ? nothing : bias["weight"]))
    end
    signature=[(r["bearing"],r["status"],r["inferred_peer"],r["candidates"]) for r in rows]
    if signature!=get(state,"signature",nothing)
        push!(state["records"],D("us"=>now,"rows"=>rows))
        length(state["records"])>PEER_IDENTITY_RULES.records && popfirst!(state["records"])
        state["signature"]=signature
    end
    state["observations"]+=1
    state["current"]=rows
end
