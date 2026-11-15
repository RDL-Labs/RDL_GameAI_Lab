using JSON3,Test
root,original=abspath.(ARGS)
rows=[JSON3.read(line,Dict{String,Any}) for line in eachline(joinpath(root,"newcomer_audit.jsonl"))]
events=filter(r->r["type"]=="event",rows)
observations=filter(r->r["type"]=="observation",rows)
plans=filter(r->r["type"]=="plan",rows)
day_us=JSON3.read(read(joinpath(root,"input.json"),String)).clock.day_us
stamp(t)=(day=div(t,day_us)+1,second=rem(t,day_us)/1e6)
incoming=filter(r->r["status"]=="offered" && r["terms"]["target"]=="npc_e",events)
observed_offers=filter(r->r["status"]=="offered" && r["scene"]!==nothing,observations)
paired=filter(r->r["status"]!="offered" && r["scene"]!==nothing && r["prior"]!==nothing,observations)
plan_rows=[merge(stamp(r["us"]),(partner=r["offer"]["proposer"],offer=r["offer"]["id"],presentation=r["presentation"],evidence=r["evidence"],past_episodes=length(r["receipts"]))) for r in plans]
misses=Dict{String,Int}()
pair_losses=Dict{String,Int}()
for o in observed_offers
 endings=filter(e->e["offer"]==o["offer"] && e["status"]!="offered",events)
 reason=if isempty(endings)
  "no_result_signal"
 elseif first(endings)["actor"]=="npc_e"
  "own_response_excluded"
 else
  final=only(filter(r->r["offer"]==o["offer"] && r["status"]!="offered",observations))
  final["scene"]!==nothing ? "paired" : "result_not_visible_or_attended"
 end
 pair_losses[reason]=get(pair_losses,reason,0)+1
end
for o in observations
 o["status"]=="offered" || continue
 e=only(filter(r->r["us"]==o["us"] && r["offer"]==o["offer"] && r["status"]==o["status"],events))
 reason=if o["scene"]!==nothing
  "visible"
 elseif !e["e_attending"]
  "not_attending"
 else
  dx=e["actor_position"][1]-e["e_position"][1];dz=e["actor_position"][2]-e["e_position"][2]
  sn,cs=sincosd(e["e_yaw"]);angle=atand(dx*cs-dz*sn,dx*sn+dz*cs)
  abs(angle)>90 ? "outside_fov" : hypot(dx,dz)>12 ? "beyond_range" : "other_visibility"
 end
 misses[reason]=get(misses,reason,0)+1
end
left=JSON3.read(read(joinpath(root,"run/result.json"),String),Dict{String,Any})
right=JSON3.read(read(joinpath(original,"run/result.json"),String),Dict{String,Any})
differences=[k for k in union(keys(left),keys(right)) if get(left,k,nothing)!=get(right,k,nothing)]
@test isempty(differences)
summary=(result_json_all_keys_equal=isempty(differences),events=length(events),incoming_to_e=length(incoming),
 e_executed_results=count(r->r["actor"]=="npc_e" && r["status"] in ("exchanged","declined"),events),
 received_event_callbacks=length(observations),observed_presentations=length(observed_offers),
 observation_breakdown=misses,observed_offer_outcome_breakdown=pair_losses,completed_observed_pairs=[merge(stamp(r["us"]),(offer=r["offer"],prior=r["prior"],observation=r["observation"])) for r in paired],
 plan_rows=plan_rows,incoming=[merge(stamp(r["us"]),(actor=r["actor"],offer=r["offer"],attending=r["e_attending"])) for r in incoming])
write(joinpath(root,"audit_summary.json"),JSON3.write(summary));println(JSON3.write(summary))
