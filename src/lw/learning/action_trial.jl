# Shared local trial contract. Goal evidence belongs to the caller; closing a
# child never mutates a parent goal. Forecast is frozen until this trial ends.
action_trial(id,key,goal,seconds)=D("id"=>id,"key"=>key,"goal"=>goal,
 "forecast"=>max(1.,Float64(seconds)),"elapsed"=>0.,"energy"=>0.,"H"=>0.,
 "status"=>"active","last_us"=>nothing,"evidence"=>nothing)
function action_trial_step!(trial,elapsed,energy;now=nothing,sensitivity=1.)
 trial["status"]=="active" || return false
 if now!==nothing && trial["last_us"]!==nothing
  now<trial["last_us"] && error("trial time rewind")
  now==trial["last_us"] && return false
 end
 trial["elapsed"]+=max(0.,elapsed);trial["energy"]+=max(0.,energy)
 trial["H"]=sensitivity*max(0.,(trial["elapsed"]-trial["forecast"])/trial["forecast"])
 trial["last_us"]=now
 true
end
function action_trial_close!(trial,status,evidence)
 status in ("achieved","failed","interrupted","handed_off") || error("trial terminal status")
 trial["status"]=="active" || return false
 trial["status"]=status;trial["evidence"]=evidence
 true
end
