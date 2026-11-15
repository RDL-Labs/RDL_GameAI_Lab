# Authored local visibility geometry; optional headings enables it, not normal LW.
# Elements have no anatomical labels. Unknown is nothing, never a zero feature.
const APPEARANCE_VIEW=(front_degrees=45.,side_degrees=120.,minimum_observed=3)
function appearance_visible_mask(angle)
 isfinite(angle) || error("invalid viewing angle")
 a=abs(mod(angle+180,360)-180)
 a<=APPEARANCE_VIEW.front_degrees ? (true,true,true,true,true) :
 a<=APPEARANCE_VIEW.side_degrees ? (false,true,true,true,false) : (false,false,true,false,false)
end
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
function appearance_observe(w,listener,bearing,world_features,rho;now=0,headings=nothing)
 sight=LW.social_sight(w,listener,bearing,now;illumination=1.)
 patches=Any[]
 for peer in sight["peers"]
  abs(peer["angle"])<=CALL_PROBE.identity_cone || continue
  p=w.positions[listener];q=w.positions[peer["ref"]]
  bins=appearance_resolution(hypot(q[1]-p[1],q[2]-p[2]),rho)
  quantized=feature_bins(world_features[peer["ref"]],bins)
  if headings!==nothing
   toward_listener=atand(p[1]-q[1],p[2]-q[2])
   mask=appearance_visible_mask(toward_listener-headings[peer["ref"]])
   quantized=ntuple(i->mask[i] ? quantized[i] : nothing,5)
  end
  push!(patches,(features=quantized,bins=bins))
 end
 (patches=patches,complete=sight["coverage"]=="complete")
end
function appearance_identify(memory,listener,view)
 memory.owner==listener || error("appearance memory owner mismatch")
 (!view.complete || length(view.patches)!=1) && return (status=isempty(view.patches) ? :unseen : :multiple_visible,peer=nothing,candidates=String[])
 patch=only(view.patches)
 observed=count(x->x!==nothing,patch.features)
 candidates=sort!([peer for (peer,features) in memory.features if all(i->patch.features[i]===nothing || feature_bins(features,patch.bins)[i]==patch.features[i],1:5)])
 observed<APPEARANCE_VIEW.minimum_observed && return (status=:insufficient_observation,peer=nothing,candidates=candidates)
 (status=isempty(candidates) ? :unknown : length(candidates)>1 ? :ambiguous : :recognized,
  peer=length(candidates)==1 ? only(candidates) : nothing,candidates=candidates)
end
function attend_appearance(w,listener,own_name,cue,world_features,memory,relations,names;rho=:coarse,headings=nothing)
 if cue===nothing || cue.text!=own_name*"！"
  return (status=cue===nothing ? :not_heard : :not_addressed,peer=nothing,candidates=String[],relation=nothing,name=nothing,view=nothing)
 end
 view=appearance_observe(w,listener,cue.bearing,world_features,rho;headings)
 identity=appearance_identify(memory,listener,view)
 relation=identity.peer===nothing ? nothing : LW.social_relation_bias(relations,identity.peer,"give")
 name=identity.peer===nothing ? nothing : recall_peer_name(names,listener,identity)
 merge(identity,(relation=relation,name=name,view=view))
end
