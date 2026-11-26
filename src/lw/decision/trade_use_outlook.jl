# Frozen, owner-local one-meal reachability. Recipes use the existing initial
# cooking knowledge and current reachable facilities; no peer inventory access.
# Opt-in scene.trade_use_outlook, default false. Multi-acquisition plans deferred.
# Existing food trade calibration, abstract utility units (not nutrient energy).
const TRADE_USE_RULE=(base_value=.2,body_gain=.6)
function trade_use_model(map,kitchen,body,gut,salts)
 recipes=Any[]
 for kind in RDLBody.FOOD_KIND_IDS, mode in (:eat,:cook,:salted)
  forecast=food_use_forecast(map,kitchen===nothing ? nothing : kitchen.foods,
   kitchen===nothing ? nothing : kitchen.actor,kind,mode!=:eat,gut,body_energy(body),
   kitchen===nothing ? () : kitchen.facilities,kitchen===nothing ? (0.,0.) : kitchen.position;
   processing=kitchen!==nothing && kitchen.processing,salted=mode==:salted)
  forecast===nothing && continue
  nutrition=food_nutrient_trade_evidence(map,gut,forecast.output)
  value=TRADE_USE_RULE.base_value+TRADE_USE_RULE.body_gain*body_demand(body)+food_taste_value(forecast.liking,body_energy(body),gut)+nutrition.utility-forecast.cost-food_condition_aversion(map,kind)
  push!(recipes,D("input"=>kind,"salt"=>Int(mode==:salted),"output"=>forecast.output,"value"=>value))
 end
 D("recipes"=>recipes,"salt_refs"=>copy(salts))
end
function trade_use_outlook(stock,salt_count,model)
 best=0.;goal=0
 for recipe in model["recipes"]
  stock[recipe["input"]]>0 && salt_count>=recipe["salt"] || continue
  if recipe["value"]>best;best=recipe["value"];goal=recipe["output"];end
 end
 (value=best,goal=goal)
end
trade_use_salts(items,model)=count(r->r["ref"] in model["salt_refs"],Iterators.flatten((items["held"],items["stored"])))
function trade_use_delta(before,after,before_salt,after_salt,weights,model)
 initial=trade_use_outlook(before,before_salt,model);final=trade_use_outlook(after,after_salt,model)
 old_food=sum(weights[k]*(log1p(after[k])-log1p(before[k])) for k in eachindex(weights))
 (correction=final.value-initial.value-old_food,before=initial,after=final)
end
# Equivalent perceived possessions and food quantities predict no changed outcome.
# This compares feature bundles, not item IDs or a ban on same-kind quantities.
function trade_use_equivalent(prepared,give,want,gf,wf)
 gf==wf || return false
 counts=Dict{String,Int}()
 for (ids,sign) in ((give,-1),(want,1)), id in ids
  feature=get(prepared.by_ref,id,nothing);feature===nothing && return false
  key=incidental_item_key(feature);counts[key]=get(counts,key,0)+sign
 end
 all(iszero,values(counts))
end
