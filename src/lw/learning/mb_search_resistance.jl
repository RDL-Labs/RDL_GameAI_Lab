# Negative search evidence belongs to food expectation, never to geometry/home.
mb_search_resistance_enabled(s)=get(s,"food_search_resistance_enabled",false)
function mb_search_resistance_state!(s)
 get!(() -> D("effort"=>D(),"directions"=>D(),"observations"=>0,"scans"=>0,"passes"=>0,
     "released"=>0,"projected"=>0,"selected"=>0,"records"=>Any[]),s,"food_search_resistance")
end
function mb_search_resistance_observe!(s,move,obs,receipt,now;rho="off")
 mb_search_resistance_enabled(s) || return
 f=s["current"];(f===nothing || s["current_us"]!=now || !haskey(s["nodes"],f.key)) && return
 r=mb_search_resistance_state!(s);effort=r["effort"]
 if !isempty(get(move,"visible",Any[]))
  get(effort,f.key,0.)>0 && (r["released"]+=1)
  delete!(effort,f.key)
 end
 # Require the next observation of an actual food-search action, not idle ticks.
 (receipt===nothing || receipt["now"]+1_000_000!=now || receipt["goal"]!="food" || receipt["status"]!="performed") && return
 action=receipt["action"];action in ("scan","walk","run") || return
 if action in ("walk","run") && receipt["distance"]>0 && haskey(s["nodes"],receipt["from"])
  dirs=get!(() -> D(),r["directions"],receipt["from"])
  dirs[string(round(Int,receipt["offset"]/30))]=f.key
 end
 isempty(get(move,"visible",Any[])) || return
 quality=(get(obs,"coverage","partial")=="complete" && get(move,"food_coverage","partial")=="complete" ? 1. : .25)
 quality*=rho=="fine" ? 1. : rho=="coarse" ? .25 : .5
 amount=quality*(action=="scan" ? 1. : .02)
 effort[f.key]=get(effort,f.key,0.)+amount
 r["observations"]+=1;r[action=="scan" ? "scans" : "passes"]+=1
 # Retention follows the MB map, never hidden world positions.
 if mod(r["observations"],256)==0
  filter!(p->haskey(s["nodes"],first(p)),effort)
  filter!(p->haskey(s["nodes"],first(p)),r["directions"])
 end
end
function mb_search_resistance_project!(s,options,goal,move,now)
 mb_search_resistance_enabled(s) && goal=="food" && isempty(get(move,"visible",Any[])) || return options
 f=s["current"];(f===nothing || s["current_us"]!=now) && return options
 r=mb_search_resistance_state!(s);dirs=get(r["directions"],f.key,D())
 for p in options
  action=p["action"];action in ("walk","run","scan") || continue
  # Rechecking/abandoning a route is an uncertainty operation, not visiting a place.
  haskey(p,"mb_control") && continue
  key=get(p,"mb_expected",nothing)
  if key===nothing && action=="scan"
   key=f.key
  elseif key===nothing && action in ("walk","run")
   angle=get(p,"steering_angle",get(p,"approach_angle",ANGLES[get(p,"direction",0)+1]))
   key=get(dirs,string(round(Int,wrap_angle(angle-f.anchor)/30)),nothing)
  end
  key===nothing && continue
  burden=get(r["effort"],key,0.);burden>0 || continue
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
