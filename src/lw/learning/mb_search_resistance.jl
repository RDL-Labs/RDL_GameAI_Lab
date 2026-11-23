# Negative search evidence belongs to food expectation, never to geometry/home.
mb_search_resistance_enabled(s)=get(s,"food_search_resistance_enabled",true)
function mb_search_resistance_state!(s)
 get!(() -> D("effort"=>D(),"directions"=>D(),"observations"=>0,"scans"=>0,"passes"=>0,
     "released"=>0,"projected"=>0,"selected"=>0,"records"=>Any[]),s,"food_search_resistance")
end
function mb_search_place!(r,key)
 places=get!(() -> D(),r,"places")
 get!(() -> D("balance"=>forecast_difference_state(),"seen"=>0.,"found"=>0.,"last_us"=>nothing),places,key)
end
# Direct contact/visible-empty evidence concerns future food availability only.
# Repeated identical empty observations do not repeatedly charge the same loss.
function mb_search_site_observe!(s,ref,remaining,now)
 mb_search_resistance_enabled(s) || return
 f=s["current"]
 r=mb_search_resistance_state!(s)
 bindings=get!(() -> Dict{Int,Any}(),r,"sites")
 site=get!(() -> D("H"=>0.,"scenes"=>String[]),bindings,Int(ref))
 f!==nothing && !(f.key in site["scenes"]) && push!(site["scenes"],f.key)
 filter!(key->haskey(s["nodes"],key),site["scenes"])
 balance=forecast_difference_state()
 forecast_difference!(balance,SEARCH_PLACE_RULES.confirmed_empty,remaining>0 ? SEARCH_PLACE_RULES.confirmed_empty : 0.)
 site["balance"]=balance;site["H"]=balance["H"]
 # This is a last-observed availability hypothesis, not a new failed harvest.
 site["observed_us"]=now
end
function mb_search_place_H(r,key)
 h=get(r["effort"],key,0.)
 for site in values(get(r,"sites",Dict{Int,Any}()))
  key in site["scenes"] && (h=max(h,site["H"]))
 end
 h
end
function mb_search_resistance_observe!(s,move,obs,receipt,now;rho="off")
 mb_search_resistance_enabled(s) || return
 f=s["current"];(f===nothing || s["current_us"]!=now || !haskey(s["nodes"],f.key)) && return
 r=mb_search_resistance_state!(s);effort=r["effort"]
 found=any(v->get(v,"acquisition","pickup")!="fishing",get(move,"visible",Any[]))
 if found
  get(effort,f.key,0.)>0 && (r["released"]+=1)
  delete!(effort,f.key)
    place=mb_search_place!(r,f.key)
    place["balance"]=forecast_difference_state()
    for visible in get(move,"visible",Any[])
     get(visible,"acquisition","pickup")=="fishing" && continue
     site=get(get(r,"sites",Dict{Int,Any}()),visible["ref"],nothing)
     site!==nothing && site["H"]>0 && mb_food_site_observe!(s,visible["ref"],1,now,"visible")
    end
 end
 for ref in get(move,"empty_food_sites",Int[])
  mb_food_site_observe!(s,ref,0,now,"visible_empty")
 end
 # Require the next observation of an actual food-search action, not idle ticks.
 (receipt===nothing || receipt["now"]+1_000_000!=now || receipt["goal"]!="food" || receipt["status"]!="performed") && return
 action=receipt["action"];action in ("scan","walk","run") || return
 if action in ("walk","run") && receipt["distance"]>0 && haskey(s["nodes"],receipt["from"])
  dirs=get!(() -> D(),r["directions"],receipt["from"])
  dirs[string(round(Int,receipt["offset"]/30))]=f.key
 end
 # No sensor result is unknown, not zero food. Coverage is evidence strength,
 # never a claim that the entire world/scene has been exhaustively inspected.
 haskey(move,"food_coverage") || return
 place=mb_search_place!(r,f.key)
 place["last_us"]==now && return
 place["last_us"]=now
 quality=(get(obs,"coverage","partial")=="complete" && move["food_coverage"]=="complete" ? 1. : SEARCH_PLACE_RULES.partial)
 quality*=rho=="fine" ? 1. : rho=="coarse" ? SEARCH_PLACE_RULES.coarse : SEARCH_PLACE_RULES.normal
 quality*=action=="scan" ? 1. : SEARCH_PLACE_RULES.pass
 expected=(SEARCH_PLACE_RULES.prior+place["found"])/(1+place["seen"])
 # Freeze the expectation before learning from this observation.
 forecast_difference!(place["balance"],quality*expected,quality*(found ? 1. : 0.))
 place["seen"]+=quality;place["found"]+=found ? quality : 0.
 found ? delete!(effort,f.key) : (effort[f.key]=place["balance"]["H"])
 r["observations"]+=1;r[action=="scan" ? "scans" : "passes"]+=1
 # Retention follows the MB map, never hidden world positions.
 if mod(r["observations"],256)==0
  filter!(p->haskey(s["nodes"],first(p)),effort)
  filter!(p->haskey(s["nodes"],first(p)),r["directions"])
  filter!(p->haskey(s["nodes"],first(p)),r["places"])
  for site in values(get(r,"sites",Dict{Int,Any}()))
   filter!(key->haskey(s["nodes"],key),site["scenes"])
  end
 end
end
function mb_search_resistance_project!(s,options,goal,move,now)
 mb_search_resistance_enabled(s) && goal=="food" || return options
 f=s["current"];(f===nothing || s["current_us"]!=now) && return options
 r=mb_search_resistance_state!(s);dirs=get(r["directions"],f.key,D())
 for p in options
  action=p["action"];action in ("walk","run","scan") || continue
  # Rechecking/abandoning a route is an uncertainty operation, not visiting a place.
  haskey(p,"mb_control") && continue
  # Current positive evidence can override an old absence hypothesis.
  ref=get(p,"food_ref",nothing)
  ref!==nothing && any(v->v["ref"]==ref,get(move,"visible",Any[])) && continue
  key=get(p,"mb_expected",nothing)
  if key===nothing && action=="scan"
   key=f.key
  elseif key===nothing && action in ("walk","run")
   angle=get(p,"steering_angle",get(p,"approach_angle",ANGLES[get(p,"direction",0)+1]))
   key=get(dirs,string(round(Int,wrap_angle(angle-f.anchor)/30)),nothing)
  end
  burden=key===nothing ? 0. : mb_search_place_H(r,key)
  site=get(get(r,"sites",Dict{Int,Any}()),ref,nothing)
  site!==nothing && (burden=max(burden,site["H"]))
  burden>0 || continue
  penalty=log1p(burden)
  p["priority"]-=penalty;p["mb_search_resistance"]=D("scene"=>key,"effort"=>burden,"penalty"=>penalty)
  r["projected"]+=1
 end
 options
end
function mb_search_resistance_selected!(s,p,now)
 haskey(p,"mb_search_resistance") || return
 r=mb_search_resistance_state!(s);r["selected"]+=1
 push!(r["records"],merge(D("us"=>now,"method"=>p["method"]),p["mb_search_resistance"]))
 length(r["records"])>64 && popfirst!(r["records"])
end
