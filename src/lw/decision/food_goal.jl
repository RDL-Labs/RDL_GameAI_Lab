# Purpose -> remembered source -> navigation. No world positions or live stock.
function food_goal_sources(map,visible)
 sources=Dict{Int,Any}()
 for c in values(get(map,"chunks",D()))
  c["goal"]=="food" && get(c,"successes",0)>0 && haskey(c,"food_ref") || continue
  ref=Int(c["food_ref"])
  strength=mb_chunk_depth(c)
  old=get(sources,ref,nothing)
  (old===nothing || strength>old["strength"]) && (sources[ref]=D("ref"=>ref,"strength"=>strength))
 end
 for v in visible;delete!(sources,Int(v["ref"]));end
 [sources[k] for k in sort(collect(keys(sources)))]
end
function food_goal_refs(map,p)
 haskey(p,"food_ref") && return Int[p["food_ref"]]
 id=get(p,"mb_chunk",get(get(p,"mb_goal_cue",D()),"chunk",nothing))
 c=get(get(map,"chunks",D()),id,nothing)
 c!==nothing && haskey(c,"food_ref") && return Int[c["food_ref"]]
 path=get(p,"mb_path",String[]);isempty(path) && return Int[]
 e=get(map["edges"],last(path),nothing);e===nothing && return Int[]
 unique(Int[c["food_ref"] for c in values(map["chunks"]) if c["goal"]=="food" && c["to"]==e["to"] && haskey(c,"food_ref")])
end
function food_goal_matches(map,p)
 choice=get(get(map,"acquisition",D()),"choice",nothing)
 choice===nothing && return true # Explicit compatibility for callers without acquisition.
 refs=food_goal_refs(map,p)
 isempty(refs) && return false # Unbound food routes are not a selected source.
 get(choice,"ref",nothing) in refs
end
function food_goal_route_filter!(map,options,goal)
 goal=="food" || return options
 filter!(p->food_goal_matches(map,p),options)
 options
end
function food_goal_node_matches(map,node)
 choice=get(get(map,"acquisition",D()),"choice",nothing)
 choice===nothing && return true
 ref=get(choice,"ref",nothing);ref===nothing && return false
 any(c->c["goal"]=="food" && c["to"]==node && get(c,"food_ref",nothing)==ref,values(map["chunks"]))
end
function food_goal_navigation_filter!(map,options,goal)
 goal=="food" || return options
 filter!(options) do p
  haskey(p,"mb_control") && return true # Recheck/abandon remains available.
  bound=haskey(p,"mb_path") || haskey(p,"mb_chunk") || haskey(p,"mb_goal_cue")
  !bound || food_goal_matches(map,p)
 end
 options
end
