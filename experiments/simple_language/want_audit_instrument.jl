# Observer-only instrumentation in a fresh experiment copy. No selection changes.
const WANT_AUDIT_TIMES=(362942000000,380222000000,432062000000,518462000000)
want_audit_window(now)=any(t->t-4_000_000<=now<=t+32_000_000,WANT_AUDIT_TIMES)
function want_audit_emit(event,now,actor;kwargs...)
 want_audit_window(now) || return
 open(joinpath(OUTPUT,"direct_audit.jsonl"),"a") do io
  println(io,JSON3.write((event=event,us=now,actor=actor,data=Dict(string(k)=>v for (k,v) in kwargs))))
 end
end
function want_audit_replace(path,old,new)
 text=read(path,String);@assert length(findall(old,text))==1 old
 write(path,replace(text,old=>new))
end
function want_audit_instrument!(output)
 day=joinpath(output,"source/src/lw/simulation/day.jl")
 marker="            if plan===nothing && item_exchange_enabled && incidental_items!==nothing && !observing && !(phase in (\"night\",\"orientation\")) && at_home && w.inventory[a]==0"
 want_audit_replace(day,marker,"            want_audit_emit(\"trade_gate\",now,a; prior_plan=plan,inventory=w.inventory[a],at_home,observing,phase)\n"*marker)
 social=joinpath(output,"source/src/lw/decision/item_social.jl")
 marker="    require_need && error(\"necessity admission was replaced by compound trade valuation\")"
 want_audit_replace(social,marker,"    want_audit_emit(\"plan_entry\",now,state[\"actor\"]; view_missing=view===nothing,incoming=view===nothing ? nothing : view[\"incoming\"],allow_start,stock,body,social=get(state,\"social\",nothing)===nothing ? nothing : Dict(k=>get(state[\"social\"],k,nothing) for k in (\"next_us\",\"pending\")))\n"*marker)
 marker="    loop.trial===nothing || return nothing"
 want_audit_replace(social,marker,"    want_audit_emit(\"trial_gate\",now,state[\"actor\"];role,trial=loop.trial)\n"*marker)
 marker="        gain===nothing && return"
 want_audit_replace(social,marker,"        gain===nothing && (want_audit_emit(\"gain_unavailable\",now,state[\"actor\"];other,available,gf,wf,counter);return)")
 marker="        subjective>=-.01 || return"
 want_audit_replace(social,marker,"        want_audit_emit(\"valuation\",now,state[\"actor\"];other,available,gf,wf,counter,gradient)\n"*marker)
 voice=joinpath(output,"source/src/lw/configured_paths/voice_request.jl")
 marker="   if plan!==nothing"
 want_audit_replace(voice,marker,"   want_audit_emit(\"request_choice\",now,actor;plan,identity,partners=selected[\"trade_partners\"],gradient=get(projected,\"gradient_maps\",nothing))\n"*marker)
end
