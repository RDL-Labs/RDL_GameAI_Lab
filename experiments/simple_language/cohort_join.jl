# Explicit experiment-only checkpoint migration. Add one fresh actor, preserve
# existing state/IDs/RNG. No global relaxation of checkpoint validation.
function cohort_source_hash(root)
 files=sort([joinpath(d,f) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl")])
 bytes2hex(sha256(join([relpath(f,root)*":"*bytes2hex(sha256(read(f))) for f in files],"\n")))
end
function cohort_owned_digest(state,actor)
 owned=Dict{Symbol,Any}(k=>v[actor] for (k,v) in state if v isa AbstractDict && haskey(v,actor))
 for key in (:w,:foods)
  object=state[key]
  for field in fieldnames(typeof(object))
   v=getfield(object,field)
   v isa AbstractDict && haskey(v,actor) && (owned[Symbol(key,"_",field)]=v[actor])
  end
 end
 io=IOBuffer();serialize(io,owned);bytes2hex(sha256(take!(io)))
end
function cohort_add_slots!(target,fresh,paths,path="state",visited=IdDict{Any,Bool}())
 target===nothing && return
 haskey(visited,target) && return
 if target isa AbstractDict && fresh isa AbstractDict
  visited[target]=true
  if haskey(fresh,"npc_e")
   @assert !haskey(target,"npc_e") "new actor already present at $path"
   target["npc_e"]=fresh["npc_e"];push!(paths,path)
   return # existing actors' internals must never be merged
  end
  for key in intersect(keys(target),keys(fresh))
   cohort_add_slots!(target[key],fresh[key],paths,"$path/$key",visited)
  end
 elseif typeof(target)==typeof(fresh) && ismutabletype(typeof(target)) && !(target isa AbstractArray)
  visited[target]=true
  for field in fieldnames(typeof(target))
   cohort_add_slots!(getfield(target,field),getfield(fresh,field),paths,"$path/$field",visited)
  end
 end
end
function cohort_join_checkpoint(path,identity,code,days,fresh)
 MODE=="continue" && return checkpoint_load(path,identity,code,days)
 prior=deserialize(path)
 base_identity=JSON3.read(read(joinpath(BASE,"input.json"),String),Dict{String,Any})
 pop!(base_identity["config"],"days")
 @assert prior.format=="lw-daily-v1" && prior.julia==string(VERSION)
 @assert prior.code==cohort_source_hash(joinpath(BASE,"source/src"))
 @assert prior.identity==base_identity && prior.day==STARTDAY && prior.day<days
 @assert Set(keys(prior.state))==Set(LW_CHECKPOINT_FIELDS)
 training=deserialize(joinpath(abspath(ARGS[4]),"checkpoints/day-003.jls"))
 @assert training.day==3 && training.julia==string(VERSION)
 @assert training.code==cohort_source_hash(joinpath(abspath(ARGS[4]),"source/src"))
 @assert !haskey(prior.state[:w].positions,"npc_e")
 state=prior.state
 before=Dict(a=>cohort_owned_digest(state,a) for a in ("npc_a","npc_b","npc_c","npc_d"))
 home_activity_attach!(fresh[:storage_stats],fresh[:w].positions,identity["scene"]["home"],STARTDAY*identity["clock"]["day_us"])
 paths=String[];cohort_add_slots!(state,fresh,paths)
 # Transfer only the new actor's actual tasting experience and physiology.
 # No navigation/social/communication memories or training leftovers are imported.
 donor=training.state
 tastes=deepcopy(donor[:mb_maps]["npc_e"]["food_taste_experiences"])
 offset=(STARTDAY-3)*identity["clock"]["day_us"]
 for entry in values(tastes);entry["last_us"]+=offset;end
 state[:mb_maps]["npc_e"]["food_taste_experiences"]=tastes
 state[:mb_maps]["npc_e"]["tasting_training"]=D("kinds"=>[1,4,8],"completed_us"=>STARTDAY*identity["clock"]["day_us"])
 state[:w].bodies["npc_e"]=deepcopy(donor[:w].bodies["npc_e"])
 state[:guts]["npc_e"]=deepcopy(donor[:guts]["npc_e"])
 identity_memory=configured_peer_identity_memory("npc_e",identity["scene"]["peer_identity_roster"])
 empty!(identity_memory["names"]);empty!(identity_memory["features"])
 state[:relations]["npc_e"]["identity_observation"]=identity_memory
 @test isempty(state[:relations]["npc_e"]["peers"])
 @test isempty(CHANNEL_MEMORIES["npc_e"].roles.associations)
 @test isempty(CHANNEL_MEMORIES["npc_e"].words.evidence)
 @test state[:w].inventory["npc_e"]==state[:stores]["npc_e"]==0
 @test all(configured_tasted(state[:mb_maps]["npc_e"],k) for k in (1,4,8))
 @test all(cohort_owned_digest(state,a)==hash for (a,hash) in before)
 @test food_audit!(state[:foods],state[:w],state[:stock],state[:shared],state[:stores])===nothing
 @test food_age_audit!(state[:foods])===nothing
 @test item_audit!(state[:items],state[:w])===nothing
 # A migratied checkpoint is explicitly written with its new identity/code.
 migrated=merge(prior,(code=code,identity=identity,state=state))
 serialize(joinpath(OUTPUT,"joined_checkpoint.jls"),migrated)
 write(joinpath(OUTPUT,"join_audit.json"),JSON3.write((old_day=STARTDAY,added_actor="npc_e",added_slots=paths,
  original_owned_digest=before,old_owned_states_preserved=true,new_tastes=tastes,new_communication_empty=true,new_social_empty=true,
  body=state[:w].bodies["npc_e"],initial_stock=0,training_source=abspath(ARGS[4]))))
 checkpoint_load(joinpath(OUTPUT,"joined_checkpoint.jls"),identity,code,days)
end
