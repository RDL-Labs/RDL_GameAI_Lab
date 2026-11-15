# Diagnostic replay only: append observations, never change selection or RNG.
ENV["RDL_LEARNED_TRADE"]="1"
const AUDIT_HERE=@__DIR__
function prepare_newcomer_audit(output)
 channel=joinpath(output,"communication/trade_channels.jl")
 code=read(channel,String)
 code=replace(code,"offer_id=result[\"offer_id\"]"=>"offer_id=result[\"offer_id\"]; audit_event!(observers,s,w,actor,op,action,now,result,speech,gesture)")
 code=replace(code,"        if status==\"offered\""=>"        observer==\"npc_e\" && audit_observation!(memory,observation,scene,offer_id,status,now)\n        if status==\"offered\"")
 write(channel,code)
 planner=joinpath(output,"communication/learned_living.jl")
 code=read(planner,String)
 code=replace(code," item_social_plan!(state,view,body,gut,stock,now;communication=evidence,kwargs...)"=>" audit_plan!(state,view,now,evidence)\n item_social_plan!(state,view,body,gut,stock,now;communication=evidence,kwargs...)")
 write(planner,code)
end
function audit_write(row)
 open(joinpath(OUTPUT,"newcomer_audit.jsonl"),"a") do io
  println(io,JSON3.write(row))
 end
end
function audit_event!(observers,s,w,actor,op,action,now,result,speech,gesture)
 haskey(w.positions,"npc_e") || return
 settings=get(observers,"npc_e",nothing)
 audit_write((type="event",us=now,actor=actor,op=op,action=action,status=result["status"],offer=result["offer_id"],
  terms=get(s["offers"],result["offer_id"],nothing),speech=speech,gesture=gesture,
  e_attending=settings===nothing ? nothing : settings.attending,
  e_position=w.positions["npc_e"],actor_position=w.positions[actor],e_yaw=settings===nothing ? nothing : settings.yaw))
end
function audit_observation!(memory,observation,scene,offer,status,now)
 audit_write((type="observation",us=now,offer=offer,status=status,observation=observation,scene=scene,
  prior=get(memory.pending,offer,nothing),episodes=length(memory.roles.receipts)))
end
function audit_plan!(state,view,now,evidence)
 state["actor"]=="npc_e" || return
 (view===nothing || isempty(get(view,"incoming",Any[]))) && return
 offer=first(view["incoming"]);memory=CHANNEL_MEMORIES["npc_e"]
 audit_write((type="plan",us=now,offer=offer,presentation=get(memory.pending,offer["id"],nothing),
  evidence=evidence,receipts=memory.roles.receipts))
end
code=read(joinpath(AUDIT_HERE,"cohort_run.jl"),String)
needle="cp(HERE,joinpath(OUTPUT,\"communication\"))"
@assert length(findall(needle,code))==1
code=replace(code,needle=>needle*"\nprepare_newcomer_audit(OUTPUT)")
include_string(Main,code,joinpath(AUDIT_HERE,"cohort_run.jl"))
