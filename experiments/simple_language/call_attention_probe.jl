# Local-only fixed attention adapter. No normal LW inclusion.
# Authored hearing radius/direction; future auditory perception replaces geometry shortcut.
const CALL_PROBE=(radius=8.,bearing_step=15.,identity_cone=15.)
function call_observation(w,source,listener,text)
 w.hearing[listener] || return nothing
 p=w.positions[listener];q=w.positions[source];dx,dz=q[1]-p[1],q[2]-p[2]
 hypot(dx,dz)<=CALL_PROBE.radius || return nothing
 (text=text,bearing=CALL_PROBE.bearing_step*round(atand(dx,dz)/CALL_PROBE.bearing_step))
end
function attend_call(w,listener,own_name,observation,relations;now=0)
 observation===nothing && return (status=:not_heard,peer=nothing,relation=nothing)
 observation.text==own_name*"！" || return (status=:not_addressed,peer=nothing,relation=nothing)
 # No source ID is available here. A seen person near the bearing is a provisional match.
 view=LW.social_sight(w,listener,observation.bearing,now;illumination=1.)
 candidates=filter(p->abs(p["angle"])<=CALL_PROBE.identity_cone,view["peers"])
 view["coverage"]=="complete" && length(candidates)==1 || return (status=isempty(candidates) ? :unseen : :ambiguous,peer=nothing,relation=nothing)
 peer=only(candidates)["ref"]
 bias=LW.social_relation_bias(relations,peer,"give")
 (status=:visually_matched,peer=peer,relation=bias)
end
