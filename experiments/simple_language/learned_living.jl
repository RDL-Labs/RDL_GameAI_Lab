# Opt-in experimental bridge. The fixed presentation channel is unchanged.
# A received proposal can recall its observed expression until that offer expires.
# No outcome from the current transaction is used to predict itself.
include("learned_trade.jl")
const LEARNED_CHANNEL_STATS=Dict(a=>Dict("observed_proposals"=>0,"learned_predictions"=>0) for a in IDS)
function learned_channel_plan!(state,view,body,gut,stock,now;kwargs...)
 evidence=nothing
 if view!==nothing && !isempty(get(view,"incoming",Any[]))
  offer=first(view["incoming"])
  memory=CHANNEL_MEMORIES[state["actor"]]
  observed=get(memory.pending,offer["id"],nothing)
  if observed!==nothing
   LEARNED_CHANNEL_STATS[state["actor"]]["observed_proposals"]+=1
   evidence=learned_trade_evidence(memory.roles,observed[1],observed[2],offer["proposer"],offer["id"],offer["created_us"],offer["expires_us"])
   evidence===nothing || (LEARNED_CHANNEL_STATS[state["actor"]]["learned_predictions"]+=1)
  end
 end
 item_social_plan!(state,view,body,gut,stock,now;communication=evidence,kwargs...)
end
function learned_channel_checkpoint(path,identity,code,days)
 # Explicit source migration only for this experiment; ordinary loader unchanged.
 root=joinpath(BASE,"source/src")
 files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
 oldcode=bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
 prior=checkpoint_load(path,identity,oldcode,days)
 serialize(joinpath(OUTPUT,"control_checkpoint.jls"),merge(prior,(code=code,)))
 checkpoint_load(joinpath(OUTPUT,"control_checkpoint.jls"),identity,code,days)
end
