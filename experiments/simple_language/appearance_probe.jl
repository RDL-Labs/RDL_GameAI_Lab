# Isolated synthetic perception probe, not included by the life loop.
# Authored distance caps and rho bins; no biological calibration.
const APPEARANCE_PROBE=(near=2.,middle=4.,bins=(2,4,8))
const FiveFeatures=NTuple{5,Float64}
function feature_bins(features,bins)
 length(features)==5 && all(x->isfinite(x) && 0<=x<=1,features) || error("five normalized features required")
 ntuple(i->min(bins-1,floor(Int,features[i]*bins)),5)
end
function appearance_resolution(distance,rho)
 rho in (:coarse,:medium,:fine) || error("invalid rho")
 isfinite(distance) && distance>=0 || error("invalid distance")
 cap=distance<=APPEARANCE_PROBE.near ? 8 : distance<=APPEARANCE_PROBE.middle ? 4 : 2
 min(cap,rho==:coarse ? 2 : rho==:medium ? 4 : 8)
end
struct LocalAppearanceMemory
 owner::String
 features::Dict{String,FiveFeatures}
end
# World-side adapter may inspect world IDs; its output carries no peer/source ID.
# Existing sight controls range/FOV/occlusion; identity from that API is discarded.
function appearance_observe(w,listener,bearing,world_features,rho;now=0)
 sight=LW.social_sight(w,listener,bearing,now;illumination=1.)
 patches=Any[]
 for peer in sight["peers"]
  abs(peer["angle"])<=CALL_PROBE.identity_cone || continue
  p=w.positions[listener];q=w.positions[peer["ref"]]
  bins=appearance_resolution(hypot(q[1]-p[1],q[2]-p[2]),rho)
  push!(patches,(features=feature_bins(world_features[peer["ref"]],bins),bins=bins))
 end
 (patches=patches,complete=sight["coverage"]=="complete")
end
function appearance_identify(memory,listener,view)
 memory.owner==listener || error("appearance memory owner mismatch")
 (!view.complete || length(view.patches)!=1) && return (status=isempty(view.patches) ? :unseen : :multiple_visible,peer=nothing,candidates=String[])
 patch=only(view.patches)
 candidates=sort!([peer for (peer,features) in memory.features if feature_bins(features,patch.bins)==patch.features])
 (status=isempty(candidates) ? :unknown : length(candidates)>1 ? :ambiguous : :recognized,
  peer=length(candidates)==1 ? only(candidates) : nothing,candidates=candidates)
end
function attend_appearance(w,listener,own_name,cue,world_features,memory,relations,names;rho=:coarse)
 if cue===nothing || cue.text!=own_name*"！"
  return (status=cue===nothing ? :not_heard : :not_addressed,peer=nothing,candidates=String[],relation=nothing,name=nothing,view=nothing)
 end
 view=appearance_observe(w,listener,cue.bearing,world_features,rho)
 identity=appearance_identify(memory,listener,view)
 relation=identity.peer===nothing ? nothing : LW.social_relation_bias(relations,identity.peer,"give")
 name=identity.peer===nothing ? nothing : recall_peer_name(names,listener,identity)
 merge(identity,(relation=relation,name=name,view=view))
end
