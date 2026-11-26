# Counterfactual evaluations of captured REAL decision inputs; no world execution.
using Serialization,JSON3
const ROOT=abspath(ARGS[1]);const AUDIT=abspath(ARGS[2])
include(joinpath(ROOT,"source/integrations/lightweight_julia/native.jl"))
src=read(joinpath(ROOT,"source/src/lw/decision/item_social.jl"),String)
lo=first(findfirst("function item_social_plan!",src));hi=first(findnext("function item_social_executed!",src,lo))
code=src[lo:prevind(src,hi)]
code=replace(code,"function item_social_plan!("=>"function item_social_plan_relaxed!(","if use_model===nothing ? subjective<-.01 : subjective<=0."=>"if subjective<-.01")
Base.include_string(Main,code,"diagnostic-relaxed-band")
rows=Any[]
for file in sort(filter(f->startswith(f,"case-")&&endswith(f,".jls"),readdir(AUDIT)))
 saved=deserialize(joinpath(AUDIT,file));a=saved.state["actor"]
 actual=Dict(p=>copy(saved.kitchen.foods.personal[p]) for p in saved.view["trade_partners"])
 cases=Any[]
 for mode in ("current","legacy","relaxed_band","public_actual_stock")
  c=deepcopy(saved);mind=item_social_state!(c.state);mind["next_us"]=c.now
  c.map["trade_use_outlook"]=mode!="legacy"
  if mode=="public_actual_stock";c.view["observed_food_stocks"]=deepcopy(actual);end
  before=(decisions=mind["decisions"],candidates=mind["candidates"])
  fn=mode=="relaxed_band" ? item_social_plan_relaxed! : item_social_plan!
  plan=fn(c.state,c.view,c.body,c.gut,c.stock,c.now;map=c.map,kitchen=c.kitchen,relation=c.relation)
  push!(cases,D("mode"=>mode,"decisions"=>mind["decisions"]-before.decisions,"candidates"=>mind["candidates"]-before.candidates,
   "action"=>plan===nothing ? nothing : plan["action"],"subjective_gain"=>plan===nothing ? nothing : get(plan,"subjective_gain",nothing),"terms"=>plan===nothing ? nothing : get(plan,"terms",nothing)))
 end
 push!(rows,D("file"=>file,"actor"=>a,"us"=>saved.now,"stock"=>saved.stock,"actual_peer_stock"=>actual,"comparisons"=>cases))
end
write(joinpath(AUDIT,"counterfactual.json"),JSON3.write(rows));println(JSON3.write(rows))
