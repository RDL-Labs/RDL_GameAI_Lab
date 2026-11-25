# Experimental owner-local future response forecast. Not proof of reciprocity.
# scene.trade_relationship_investment defaults false. No hidden peer stock/body.
const TRADE_RELATION_FORECAST=(prior=.5,prior_weight=4.,value=1.5,h_scale=4.,band=1.,sleep_gain=.2,history_limit=64)
trade_investment_enabled(s)=s!==nothing && get(s,"trade_relationship_investment",false)
function trade_investment_peer!(s,other)
 group=get!(()->D(),s,"trade_investment")
 peer=get(get(s,"peers",D()),other,D())
 offered=get(peer,"trade_offer",D());received=get(peer,"aid_received",D())
 successes=get(offered,"exchanged",0)+get(received,"given",0)
 failures=get(offered,"declined",0)+get(received,"refuse",0)
 prior=(TRADE_RELATION_FORECAST.prior_weight*TRADE_RELATION_FORECAST.prior+successes)/(TRADE_RELATION_FORECAST.prior_weight+successes+failures)
 get!(()->D("probability"=>prior,"residual"=>0.,"variance"=>0.,
  "strength"=>0.,"pending"=>nothing,"records"=>Any[],"last_sleep"=>-1),group,other)
end
trade_investment_h(m)=sign(m["residual"])*max(0.,abs(m["residual"])-TRADE_RELATION_FORECAST.band*sqrt(m["variance"]))/TRADE_RELATION_FORECAST.h_scale
function trade_investment_forecast(s,other)
 trade_investment_enabled(s)||return nothing
 m=trade_investment_peer!(s,other)
 # Sleep strength contributes to the NEXT forecast; not also to candidate score.
 p=clamp(m["probability"]+m["strength"],0.,1.)
 D("probability"=>p,"baseline"=>TRADE_RELATION_FORECAST.prior,"value"=>TRADE_RELATION_FORECAST.value,
   "H"=>trade_investment_h(m),"strength"=>m["strength"])
end
function trade_investment_register!(s,other,source,now,forecast)
 trade_investment_enabled(s)&&forecast!==nothing||return false
 m=trade_investment_peer!(s,other)
 m["pending"]===nothing||return false # never overwrite an unresolved prediction
 m["pending"]=D("source"=>source,"us"=>now,"forecast"=>deepcopy(forecast));true
end
function trade_investment_observe!(s,event)
 trade_investment_enabled(s)||return false
 # A response to OUR later request is evidence; our own acceptance is not.
 channel=event["channel"];outcome=event["outcome"]
 channel in ("trade_offer","aid_received")||return false
 outcome in ("exchanged","declined","given","refuse")||return false
 m=get(get(s,"trade_investment",D()),event["other"],nothing)
 m===nothing&&return false
 pending=m["pending"]
 pending===nothing&&return false
 event["us"]>pending["us"] && event["source"]!=pending["source"]||return false
 success=outcome in ("exchanged","given");f=pending["forecast"];p=f["probability"];v=f["value"]
 m["residual"]+=(Float64(success)-p)*v;m["variance"]+=p*(1-p)*v^2
 # Keep learned response rate and sleep correction separate: H alone consolidates
 # here; probability remains the prior until future calibration is implemented.
 push!(m["records"],D("forecast_source"=>pending["source"],"evidence_source"=>event["source"],
  "us"=>event["us"],"expected"=>p,"observed"=>success,"H"=>trade_investment_h(m)))
 length(m["records"])>TRADE_RELATION_FORECAST.history_limit&&popfirst!(m["records"])
 m["pending"]=nothing;true
end
function trade_investment_sleep!(s,day)
 trade_investment_enabled(s)||return
 for m in values(get(s,"trade_investment",D()))
  day>m["last_sleep"]||continue
  signed=trade_investment_h(m);before=m["strength"]
  m["strength"]=clamp(before+TRADE_RELATION_FORECAST.sleep_gain*signed,-m["probability"],1-m["probability"])
  reviews=get!(()->Any[],m,"reviews")
  push!(reviews,D("day"=>day,"H"=>signed,"before"=>before,"after"=>m["strength"]))
  length(reviews)>TRADE_RELATION_FORECAST.history_limit&&popfirst!(reviews)
  # Preserve neutral-band evidence: one uncertain observation per night must not
  # be forgotten forever. Only a nonzero consolidated evaluation is discharged.
  if !iszero(signed);m["residual"]=0.;m["variance"]=0.;end
  m["last_sleep"]=day
 end
end
