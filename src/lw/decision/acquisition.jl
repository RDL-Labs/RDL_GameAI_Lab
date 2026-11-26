# Purpose -> method -> observed site. Only own outcomes enter this ledger.
# Forecasts freeze per unresolved episode; need pressure is never learned as failure.
include("../learning/action_trial.jl")
include("../learning/execution_commitment.jl")
include("../parameters.jl")
include("food_goal.jl")
acquisition_state()=D("sites"=>D(),"methods"=>D(),"choice"=>nothing,"next_us"=>0,"records"=>Any[],"active"=>nothing,"sequence"=>0,"trials"=>Any[])
acquisition_key(method,site)=string(method,":",method=="explore" ? "unknown" : site)
acquisition_episode(seconds)=D("forecast"=>max(1.,Float64(seconds)),"elapsed"=>0.,"H"=>0.,"completed"=>0)
function acquisition_publish!(state,trial;achieved=false)
 elapsed_delta=max(0.,trial["elapsed"]-get(trial,"published_elapsed",0.))
 observed_delta=achieved && !get(trial,"published_success",false) ? 1. : 0.
 for (table,key) in ((state["sites"],trial["key"]),(state["methods"],trial["method"]))
  summary=get!(() -> acquisition_episode(trial["forecast"]),table,key)
  # Each scope keeps its own frozen expectation while unresolved, including
  # across site switches. A catch is an observation, not a blanket H reset.
  if summary["H"]==0 && get(summary,"trial_id",nothing)!=trial["id"]
   summary["forecast"]=trial["forecast"]
  end
  balance=get!(() -> forecast_difference_state(summary["H"]),summary,"forecast_balance")
  sensitivity=get(trial,"sensitivity",1.)
  previous_H=balance["H"]
  forecast_difference!(balance,sensitivity*elapsed_delta/summary["forecast"],sensitivity*observed_delta)
  if observed_delta>0
   released=max(0.,previous_H-balance["H"])
   reward=forecast_success_reward(observed_delta,released)
   summary["reward"]=get(summary,"reward",0.)+reward
   forecast_reward_record!(balance,released,reward)
  end
  summary["elapsed"]+=elapsed_delta
  summary["H"]=balance["H"];summary["trial_id"]=trial["id"]
  summary["status"]=trial["status"]
  observed_delta>0 && (summary["completed"]+=1)
 end
 trial["H"]=state["sites"][trial["key"]]["H"]
 trial["published_elapsed"]=trial["elapsed"]
 achieved && (trial["published_success"]=true)
end
function acquisition_finish!(map,status,evidence;clear_choice=true)
 state=get(map,"acquisition",nothing);state===nothing && return false
 if clear_choice;state["choice"]=nothing;state["next_us"]=0;end
 trial=get(state,"active",nothing)
 trial===nothing && return false
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
function acquisition_known_sources!(map,state)
 get!(state,"known_sources") do
  # Compatibility: reconstruct only from this actor's retained observations and
  # experience. Never inspect world sites or another actor's memory.
  known=Dict{Int,Bool}()
  remember_key(key)=begin
   parts=split(string(key),':');ref=tryparse(Int,last(parts))
   ref===nothing || (known[ref]=true)
  end
  for key in keys(state["sites"]);remember_key(key);end
  for row in Iterators.flatten((get(state,"trials",Any[]),get(state,"records",Any[]),
      Any[get(state,"active",nothing),get(state,"choice",nothing)]))
   row===nothing && continue
   for key in get(row,"observed_keys",String[]);remember_key(key);end
   for candidate in get(row,"candidates",Any[])
    ref=get(candidate,"ref",nothing);ref===nothing || (known[Int(ref)]=true)
   end
   evidence=get(row,"evidence",nothing)
   evidence isa AbstractDict && haskey(evidence,"ref") && (known[Int(evidence["ref"])]=true)
  end
  for chunk in values(get(map,"chunks",D()))
   haskey(chunk,"food_ref") && (known[Int(chunk["food_ref"])]=true)
  end
  for ref in keys(get(map,"food_sites",Dict{Int,Any}()));known[Int(ref)]=true;end
  known
 end
end
function acquisition_observe!(map,visible)
 state=get!(acquisition_state,map,"acquisition")
 known=acquisition_known_sources!(map,state)
 discovered=findfirst(v->!haskey(known,Int(v["ref"])),visible)
 # Reappearance and changed condition update other observation models, but do
 # not become another discovery. Identity uses the existing perceived source ref.
 for v in visible;known[Int(v["ref"])]=true;end
 trial=get(state,"active",nothing)
 if trial===nothing || trial["method"]!="explore" || trial["elapsed"]==0;return false;end
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
 trial["sensitivity"]=sensitivity
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
 # Same catch informs two scopes; use the stronger support, not their sum.
 learned=log1p(max(get(get(s["sites"],acquisition_key(method,site),D()),"reward",0.),get(get(s["methods"],string(method),D()),"reward",0.)))
 (score=log1p(yield_units)+learned-cost-local_repulsion-method_repulsion-urgency,
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
 review=nothing
 if choice!==nothing
  site=get(get(map,"food_sites",Dict{Int,Any}()),get(choice,"ref",nothing),nothing)
  contradicted=site!==nothing && site["state"]=="empty" && get(choice,"site_state",nothing)!="empty" && site["observed_us"]>get(choice,"selected_us",now)
  commitment=get(choice,"execution",nothing)
  review=commitment===nothing ? (now>=s["next_us"] ? "forecast_elapsed" : nothing) :
      execution_review_reason(commitment,now;contradiction=contradicted)
  contradicted && (review="contradicted")
 end
 if choice!==nothing && review===nothing
  choice["ref"]===nothing && return Any[]
  i=findfirst(v->v["ref"]==choice["ref"],visible)
  i!==nothing && return Any[visible[i]]
  # All selected methods retain their target without inventing visibility.
  return Any[]
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
 # Recall sources before constructing a path. Multiple paths to one source do
 # not create extra goal votes. The existing parent estimate is a rough prior.
 remembered=food_goal_sources(map,visible)
 if !isempty(remembered)
  prior=mb_parent_estimate!(map,D(),"food",nothing;use_arrival=false)
  for source in remembered
   ref=source["ref"];seconds=Float64(prior["upper_actions"])
   technique=haskey(s["sites"],acquisition_key("fishing",ref)) ? "fishing" : "pickup"
   value=acquisition_value(map,technique,ref,seconds,1.,anxiety)
   availability=mb_food_availability(map,D("goal"=>"food","food_ref"=>ref))
   push!(rows,D("method"=>technique*":"*string(ref),"priority"=>value.score+log1p(source["strength"])+log(availability),
    "ref"=>ref,"technique"=>technique,"source"=>"memory","seconds"=>seconds,"uncertainty"=>1.,
    "food_availability"=>availability,"gradient"=>value))
  end
 end
 # Searching remains a candidate even when an old opportunity is visible.
 search=mb_parent_estimate!(map,D(),"food",nothing;use_arrival=false)
 seconds=Float64(search["upper_actions"])
 value=acquisition_value(map,"explore","unknown",seconds,1.,anxiety)
 push!(rows,D("method"=>"explore","priority"=>value.score,"ref"=>nothing,"technique"=>"explore","seconds"=>seconds,"uncertainty"=>1.,"gradient"=>value))
 # 各候補の食事までの糖予算。同じ計算を探索にも適用し、特定手段を禁止しない。
 # 探索の未知の加工時間等は既存見積もりの限界として残す。
 for candidate in rows
  forecast=food_sugar_forecast(body,get(map,"food_security",nothing),candidate["seconds"];uncertainty=candidate["uncertainty"])
  if forecast!==nothing
   candidate["sugar_forecast"]=forecast
   candidate["priority"]-=forecast["penalty"]
  end
 end
 # 暫定の関係同定: 既存techniqueを共有関係キーとする。方法の固定順位はない。
 # 将来は学習したMBのまとまりを渡す。場所数だけで親関係の重みを水増ししない。
 relation_keys=[candidate["technique"] for candidate in rows]
 probabilities=relational_candidate_distribution(loop,rows,relation_keys);u=rand(loop.rng);index=length(rows);acc=0.
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
 # A decision already priced travel, work and uncertainty. Execute
 # within that frozen forecast before comparing methods again. Safety/body
 # interruptions remain upstream; this is not a successful-catch guarantee.
 s["choice"]=selected
 selected["selected_us"]=now
 selected["site_state"]=get(get(get(map,"food_sites",Dict{Int,Any}()),selected["ref"],D()),"state",nothing)
 selected["execution"]=execution_commitment(selected["method"],now,selected["seconds"])
 s["next_us"]=selected["execution"]["review_us"]
 arrival=get(get(map,"goal_arrival",D()),"food",nothing)
 if arrival!==nothing && get(arrival,"target",nothing)!=selected["ref"]
  arrival["mode"]="search";arrival["target"]=nothing
 end
 push!(s["records"],D("us"=>now,"review_reason"=>choice===nothing ? "unselected" : review,"anxiety"=>anxiety,"choice"=>rows[index]["method"],"candidates"=>rows,"probabilities"=>probabilities,
     "relation_keys"=>relation_keys,"distribution_rule"=>"relation_peak_mass"))
 length(s["records"])>64 && popfirst!(s["records"])
 ref=rows[index]["ref"]
 ref===nothing ? Any[] : Any[v for v in visible if v["ref"]==ref]
end
