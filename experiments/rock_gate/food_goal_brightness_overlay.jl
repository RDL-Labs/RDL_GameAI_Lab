# Experimental overlay only: include after the ordinary LW implementation.
# Source availability dims food attraction, never geometry or a home relation.
# Preserve the existing empty-source quarter-strength calibration at H=1.
const LOCAL_FOOD_GOAL_RULES=(empty_brightness=.25,)
const LOCAL_FOOD_GOAL_AUDIT=Dict("availability_calls"=>0,"dimmed_calls"=>0,"wake_bound"=>0,"wake_dimmed"=>0)
function local_food_source_H(s,ref)
 ref===nothing && return 0.
 # Only the actor's last observation. No global stock or world coordinates.
 row=get(get(s,"food_sites",Dict{Int,Any}()),Int(ref),nothing)
 row===nothing && return 0.
 row["state"]=="empty" ? SEARCH_PLACE_RULES.confirmed_empty : 0.
end
local_food_brightness(H)=exp(log(LOCAL_FOOD_GOAL_RULES.empty_brightness)*H)
function mb_food_availability(s,c)
 LOCAL_FOOD_GOAL_AUDIT["availability_calls"]+=1
 h=c["goal"]=="food" ? local_food_source_H(s,get(c,"food_ref",nothing)) : 0.
 h>0 && (LOCAL_FOOD_GOAL_AUDIT["dimmed_calls"]+=1)
 local_food_brightness(h)
end
function local_food_terminal_refs(s,node)
 refs=Int[]
 # A successful food path binds its goal, not all intermediate places, to a source.
 for c in values(s["chunks"])
  c["goal"]=="food" && c["to"]==node && haskey(c,"food_ref") && push!(refs,c["food_ref"])
 end
 unique(refs)
end
function local_food_wake_project!(s,p,goal,node)
 goal=="food" || return p
 refs=local_food_terminal_refs(s,node);isempty(refs) && return p
 # Coarse scenes may represent several sources: an available alternative keeps
 # the food goal bright. Do not spread one source's absence to every relation.
 h=minimum(local_food_source_H(s,ref) for ref in refs)
 brightness=local_food_brightness(h)
 p["priority"]*=brightness
 p["food_goal_brightness"]=D("terminal"=>node,"refs"=>refs,"H"=>h,"brightness"=>brightness)
 LOCAL_FOOD_GOAL_AUDIT["wake_bound"]+=1
 h>0 && (LOCAL_FOOD_GOAL_AUDIT["wake_dimmed"]+=1)
 p
end
# Replace the separate spatial penalty for this experiment. Observation still
# learns absence; already-existing chunk/goal-cue attraction reads it at source.
mb_search_resistance_project!(s,options,goal,move,now)=options
