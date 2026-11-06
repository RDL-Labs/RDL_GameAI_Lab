# Purpose -> method -> observed site. Only own outcomes enter this ledger.
# Forecasts freeze per unresolved episode; need pressure is never learned as failure.
include("../learning/action_trial.jl")
include("../parameters.jl")
acquisition_state()=D("sites"=>D(),"methods"=>D(),"choice"=>nothing,"next_us"=>0,"records"=>Any[],"active"=>nothing,"sequence"=>0,"trials"=>Any[])
acquisition_key(method,site)=string(method,":",method=="explore" ? "unknown" : site)
acquisition_episode(seconds)=D("forecast"=>max(1.,Float64(seconds)),"elapsed"=>0.,"H"=>0.,"completed"=>0)
function acquisition_publish!(state,trial;achieved=false)
 for (table,key) in ((state["sites"],trial["key"]),(state["methods"],trial["method"]))
  summary=get!(() -> acquisition_episode(trial["forecast"]),table,key)
  summary["forecast"]=trial["forecast"];summary["elapsed"]=achieved ? 0. : trial["elapsed"]
  summary["H"]=achieved ? 0. : trial["H"];summary["trial_id"]=trial["id"]
  summary["status"]=trial["status"]
  achieved && (summary["completed"]+=1)
 end
end
function acquisition_finish!(map,status,evidence;clear_choice=true)
 state=get(map,"acquisition",nothing);state===nothing && return false
 trial=get(state,"active",nothing)
 trial===nothing && return false
 if clear_choice;state["choice"]=nothing;state["next_us"]=0;end
 action_trial_close!(trial,status,evidence) || return false
 (trial["elapsed"]>0 || status=="achieved") && acquisition_publish!(state,trial;achieved=status=="achieved")
 status=="achieved" && trial["method"]=="explore" && (state["handoff_from"]=trial["id"])
 history=get!(() -> Any[],state,"trials");push!(history,deepcopy(trial))
 length(history)>ACQUISITION_TRIAL_RULES.history_limit && popfirst!(history)
 state["active"]=nothing
 true
end
function acquisition_begin!(map,method,site,seconds;observed_keys=String[])
 state=get!(acquisition_state,map,"acquisition");key=acquisition_key(method,site)
 trial=get(state,"active",nothing)
 trial!==nothing && trial["key"]==key && return trial
 trial!==nothing && acquisition_finish!(map,"interrupted","different_candidate";clear_choice=false)
 state["sequence"]=get(state,"sequence",0)+1
 trial=action_trial(state["sequence"],key,method=="explore" ? "observed_new_acquisition_candidate" : "acquired_food",seconds)
 trial["method"]=String(method);trial["site"]=site;trial["observed_keys"]=copy(observed_keys)
 trial["predecessor"]=pop!(state,"handoff_from",nothing)
 state["active"]=trial
 trial
end
function acquisition_observe!(map,visible)
 state=get(map,"acquisition",nothing);state===nothing && return false
 trial=get(state,"active",nothing)
 if trial===nothing || trial["method"]!="explore" || trial["elapsed"]==0;return false;end
 discovered=findfirst(v->!(acquisition_key(get(v,"acquisition","pickup"),v["ref"]) in trial["observed_keys"]),visible)
 discovered===nothing && return false
 acquisition_finish!(map,"achieved",D("kind"=>"observed_candidate","ref"=>visible[discovered]["ref"]))
end
function acquisition_result!(map,method,site,seconds,elapsed,success; sensitivity=1.,now=nothing,energy=0.)
 s=get!(acquisition_state,map,"acquisition")
 if now!==nothing
  prior_us=get(s,"last_result_us",nothing)
  prior_us!==nothing && now<prior_us && error("acquisition time rewind")
  now==prior_us && return
  s["last_result_us"]=now
 end
 choice=get(s,"choice",nothing)
 observed_keys=choice===nothing ? String[] : get(choice,"observed_keys",String[])
 trial=acquisition_begin!(map,method,site,seconds;observed_keys)
 if choice!==nothing && acquisition_key(choice["technique"],get(choice,"ref",nothing))==trial["key"]
  get!(trial,"total_seconds",choice["seconds"]);get!(trial,"uncertainty",choice["uncertainty"])
 end
 action_trial_step!(trial,elapsed,energy;now,sensitivity) || return
 acquisition_publish!(s,trial)
 success && acquisition_finish!(map,"achieved","picked_up")
end
function acquisition_value(map,method,site,seconds,uncertainty,anxiety;yield_units=1.)
 s=get!(acquisition_state,map,"acquisition")
 local_H=get(get(s["sites"],acquisition_key(method,site),D()),"H",0.)
 method_H=get(get(s["methods"],string(method),D()),"H",0.)
 # Log transforms retain alternatives; no hard ban on a place or technique.
 local_repulsion=log1p(local_H)
 method_repulsion=max(0.,log1p(method_H)-local_repulsion)*anxiety/(1+anxiety)
 cost=log1p(max(0.,seconds)/1800.)
 urgency=log1p(max(0.,anxiety))*(cost+max(0.,uncertainty))
 (score=log1p(yield_units)-cost-local_repulsion-method_repulsion-urgency,
  local_H=local_H,method_H=method_H,local_repulsion=local_repulsion,
  method_repulsion=method_repulsion,urgency=urgency)
end
function acquisition_targets!(map,visible,loop,now;home=nothing,anxiety=0.,committed_ref=nothing,body=nothing,gut=nothing,owned=nothing,own_stock=nothing,held=())
 s=get!(acquisition_state,map,"acquisition")
 acquisition_observe!(map,visible)
 choice=s["choice"]
 if committed_ref!==nothing && choice!==nothing && choice["ref"]==committed_ref
  held=filter(v->v["ref"]==committed_ref,visible)
  !isempty(held) && return held
 end
 if now<s["next_us"] && choice!==nothing
  choice["ref"]===nothing && return Any[]
  i=findfirst(v->v["ref"]==choice["ref"],visible)
  i!==nothing && return Any[visible[i]]
 end
 if owned===nothing && own_stock!==nothing
  owned=copy(own_stock)
  for k in held;owned[k]+=1;end
 end
 rows=Any[]
 for v in visible
  method=get(v,"acquisition","pickup")
  travel=mb_travel_seconds(v["distance"])
  work=get(v,"acquisition_seconds",1.)
  acquire=travel+work
  # Public initial recipe knowledge; no hidden stock or world success rates.
  kind=method=="fishing" ? RDLBody.FISH_FOOD : something(findfirst(==(get(v,"appearance","")),RDLBody.FOOD_APPEARANCE),1);output=RDLBody.FOOD_PROCESS_OUTPUT[kind]
  preparation=output==0 ? 0. : RDLBody.FOOD_PROCESS_TICKS[kind]+(home===nothing ? 128. : mb_travel_seconds(home["distance"]))
  seconds=acquire+preparation
  uncertainty=get(v,"acquisition_uncertainty",0.)
  value=acquisition_value(map,method,v["ref"],seconds,uncertainty,anxiety)
  waste=0.
  if body!==nothing && owned!==nothing
   forecast=food_expiry_forecast(map,body,gut;now,delay_seconds=seconds)
   forecast["risk"][kind]=1-(1-forecast["risk"][kind])*max(.05,1-.5get(v,"condition",0))
   more=copy(owned);more[kind]+=1
   waste=max(0.,food_expected_waste(more,forecast)-food_expected_waste(owned,forecast))
  end
  push!(rows,D("method"=>string(method,":",v["ref"]),"priority"=>value.score-2waste,"expected_extra_waste"=>waste,"ref"=>v["ref"],"technique"=>method,"seconds"=>seconds,"acquire_seconds"=>acquire,"travel_seconds"=>travel,"work_seconds"=>work,"preparation_seconds"=>preparation,"uncertainty"=>uncertainty,"gradient"=>value))
 end
 # Searching remains a candidate even when an old opportunity is visible.
 search=mb_parent_estimate!(map,D(),"food",nothing;use_arrival=false)
 seconds=Float64(search["upper_actions"])
 value=acquisition_value(map,"explore","unknown",seconds,1.,anxiety)
 push!(rows,D("method"=>"explore","priority"=>value.score,"ref"=>nothing,"technique"=>"explore","seconds"=>seconds,"uncertainty"=>1.,"gradient"=>value))
 probabilities=method_distribution(loop,rows);u=rand(loop.rng);index=length(rows);acc=0.
 for i in eachindex(rows);acc+=probabilities[i];if u<acc;index=i;break;end;end
 selected=copy(rows[index])
 selected["observed_keys"]=[acquisition_key(get(v,"acquisition","pickup"),v["ref"]) for v in visible]
 selected_trial=get(s,"active",nothing)
 if selected_trial!==nothing
  if selected_trial["key"]==acquisition_key(selected["technique"],selected["ref"])
   selected["seconds"]=get!(selected_trial,"total_seconds",selected["seconds"])
   selected["uncertainty"]=get!(selected_trial,"uncertainty",selected["uncertainty"])
   haskey(selected,"acquire_seconds") && (selected["acquire_seconds"]=selected_trial["forecast"])
  else
   acquisition_finish!(map,"interrupted","different_candidate";clear_choice=false)
  end
 end
 s["choice"]=selected;s["next_us"]=now+64_000_000
 push!(s["records"],D("us"=>now,"anxiety"=>anxiety,"choice"=>rows[index]["method"],"candidates"=>rows,"probabilities"=>probabilities))
 length(s["records"])>64 && popfirst!(s["records"])
 ref=rows[index]["ref"]
 ref===nothing ? Any[] : Any[v for v in visible if v["ref"]==ref]
end
