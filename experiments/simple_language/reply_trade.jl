# Local-only reply-to-person bridge. Cue contains no sender identity.
const REPLY_TRADE=(bearing_cone=15.,step_us=1_000_000,max_steps=8)
function reply_visual_identity(world,observer,cue,roster,headings,memory;now=0,rho="fine")
 cue===nothing && return (status="not_heard",)
 sight=LW.social_sight(world,observer,cue.bearing,now;illumination=1.)
 silhouettes=filter(p->abs(p["angle"])<=REPLY_TRADE.bearing_cone,sight["peers"])
 length(silhouettes)==1 || return (status=isempty(silhouettes) ? "unseen" : "ambiguous_direction",)
 handle=only(silhouettes)["ref"]
 p=world.positions[observer];q=world.positions[handle]
 patch=LW.peer_identity_patch(roster[handle]["features"],hypot(q[1]-p[1],q[2]-p[2]),
  atand(p[1]-q[1],p[2]-q[2])-headings[handle],rho)
 identity=LW.peer_identity_match(memory["features"],patch)
 (status=identity.status,handle=handle,inferred_peer=identity.peer,
  name=identity.peer===nothing ? nothing : get(memory["names"],identity.peer,nothing),patch=patch,bearing=cue.bearing)
end
function reply_relation_projection(relation,identity)
 projected=deepcopy(relation);handle=identity.handle;peer=identity.inferred_peer
 # Decision sees a physical handle but recalls the inferred person's experience.
 # Projection is local to this encounter; never rewrite permanent person IDs.
 if handle!=peer
  if haskey(relation["peers"],peer)
   projected["peers"][handle]=deepcopy(relation["peers"][peer])
  else
   pop!(projected["peers"],handle,nothing)
  end
  if LW.social_relational(projected)
   for group in LW.social_mb_groups(projected["mb"])
    for key in collect(keys(group))
     node=group[key]
     if node["other"]==peer
      node["other"]=handle
     elseif node["other"]==handle
      delete!(group,key)
     end
    end
   end
  end
 end
 projected["social_view"]=nothing
 projected
end
function reply_trade_plan!(fixture,actor,identity,state,relation,now;requested_food=nothing)
 identity.status=="recognized" || return nothing
 view=LW.item_visible(fixture.s,fixture.w,(0.,0.),actor,identity.bearing,now;open_stores=true,foods=fixture.foods)
 # Attend only the currently seen interlocutor; no truth-ID equality gate.
 filter!(==(identity.handle),view["trade_partners"])
 filter!(o->o["proposer"]==identity.handle,view["incoming"])
 LW.item_social_observe!(state,view;relation)
 LW.item_social_plan!(state,view,fixture.w.bodies[actor],nothing,fixture.foods.personal[actor],now;relation,requested_food)
end
function reply_trade_execute!(fixture,actor,state,relation,plan,now)
 args=Dict{Symbol,Any}(Symbol(k)=>plan[k] for k in ("target","offer_id","give_items","want_items","give_food","want_food") if haskey(plan,k))
 receipt=LW.item_execute!(fixture.s,fixture.foods,fixture.w,fixture.stores,(0.,0.),actor,
  "voice-trade:$actor:$now",plan["action"],now;args...)
 LW.item_social_executed!(state,plan,receipt;relation)
 receipt
end
