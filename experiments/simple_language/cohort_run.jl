using JSON3,Test,Serialization,SHA
length(ARGS)>=3 || error("usage: cohort_run.jl continue|train|join BASE NEW_OUTPUT [TRAIN]")
const MODE,BASE,OUTPUT=ARGS[1],abspath(ARGS[2]),abspath(ARGS[3])
MODE in ("continue","train","join") || error("unknown cohort mode")
MODE=="join" && length(ARGS)!=4 && error("join requires training output")
ispath(OUTPUT) && error("fresh output required")
const HERE=@__DIR__
mkpath(OUTPUT);cp(joinpath(BASE,"source"),joinpath(OUTPUT,"source"))
cp(HERE,joinpath(OUTPUT,"communication"))
const LEARNED_CONTROL=get(ENV,"RDL_LEARNED_TRADE","0")=="1"
const WANT_VOICE=get(ENV,"RDL_WANT_VOICE","0")=="1"
if LEARNED_CONTROL
 for file in ("item_social.jl","gradient_trace.jl","trade_communication.jl","food_exchange.jl")
  cp(joinpath(HERE,"../../src/lw/decision",file),joinpath(OUTPUT,"source/src/lw/decision",file);force=true)
 end
 daypath=joinpath(OUTPUT,"source/src/lw/simulation/day.jl")
 daytext=read(daypath,String)
 daytext=replace(daytext,"plan=item_social_plan!("=>"plan=learned_channel_plan!(")
 MODE=="continue" && (daytext=replace(daytext,"saved=checkpoint_load(resume_from,checkpoint_identity,checkpoint_code,days)"=>"saved=learned_channel_checkpoint(resume_from,checkpoint_identity,checkpoint_code,days)"))
 write(daypath,daytext)
end
if WANT_VOICE
 @assert LEARNED_CONTROL
 cp(joinpath(HERE,"../../src/lw/configured_paths/voice_request.jl"),joinpath(OUTPUT,"source/src/lw/configured_paths/voice_request.jl");force=true)
 cp(joinpath(HERE,"../../src/perception/sound_level.jl"),joinpath(OUTPUT,"source/src/perception/sound_level.jl");force=true)
 voicepath=joinpath(OUTPUT,"communication/voice_broadcast.jl")
 write(voicepath,replace(read(voicepath,String),"../../src/perception/sound_level.jl"=>"../source/src/perception/sound_level.jl"))
 daypath=joinpath(OUTPUT,"source/src/lw/simulation/day.jl");daytext=read(daypath,String)
 # A continuation already contains these explicit experiment hooks.
 if !occursin("configured_want_tick!",daytext)
  needle="        trade_views=trades===nothing"
  @assert length(findall(needle,daytext))==1
  daytext=replace(daytext,needle=>"        configured_want_tick!(WANT_VOICE_STATE,w,yaw,thinking_ids,foods,relations,spec.peer_identity_roster,now)\n"*needle)
  @assert length(findall("plan=learned_channel_plan!(",daytext))==1
  daytext=replace(daytext,"plan=learned_channel_plan!("=>"plan=configured_want_plan!(WANT_VOICE_STATE,clock.day_us,")
 end
 write(daypath,daytext)
end
if WANT_VOICE
 cp(joinpath(HERE,"../../src/lw/decision/task_focus.jl"),joinpath(OUTPUT,"source/src/lw/decision/task_focus.jl");force=true)
 daypath=joinpath(OUTPUT,"source/src/lw/simulation/day.jl");daytext=read(daypath,String)
 if !occursin("configured_want_observe_meal!",daytext)
  meal_marker="                    eaten_kind=actual_kind;meal_liking=liking"
  @assert length(findall(meal_marker,daytext))==1
  daytext=replace(daytext,meal_marker=>meal_marker*"\n                    mb_simulation && configured_want_observe_meal!(mb_maps,social_views,a,actual_kind,now)")
 end
 if !occursin("task_trade_notice!",daytext)
  marker="            notice=get(fs,\"active\",false) && focus_enabled"
  @assert length(findall(marker,daytext))==1
  wake_from=parse(Int,get(ENV,"RDL_WANT_WAKE_FROM","0")) # replay-only activation boundary
  injection="            item_pending=incidental_items===nothing ? nothing : get(get(incidental_items[a],\"social\",D()),\"pending\",nothing)\n            trade_notice=item_exchange_enabled && now>=$wake_from ? task_trade_notice!(fs,items,w,a,now;pending_offer=item_pending===nothing ? nothing : item_pending[\"offer_id\"]) : nothing\n"
  daytext=replace(daytext,marker=>injection*marker)
  old="wait_notice=identity_call_notice===nothing ? task_wait_notice(fs,w.inbox[a],now) : identity_call_notice,"
  @assert length(findall(old,daytext))==1
  daytext=replace(daytext,old=>"wait_notice=trade_notice!==nothing ? trade_notice : identity_call_notice===nothing ? task_wait_notice(fs,w.inbox[a],now) : identity_call_notice,")
 end
 write(daypath,daytext)
end
input=JSON3.read(read(joinpath(BASE,"input.json"),String),Dict{String,Any})
const STARTDAY=MODE=="train" ? 0 : Int(JSON3.read(read(joinpath(BASE,"completed.json"),String)).days)
input["config"]["days"]=MODE=="train" ? 3 : STARTDAY+parse(Int,get(ENV,"RDL_COHORT_DAYS","20"))
if MODE in ("train","join")
 scene=input["scene"]
 @assert scene["experimental_actor_ids"]==["npc_a","npc_b","npc_c","npc_d"]
 push!(scene["experimental_actor_ids"],"npc_e")
 for key in ("reserve","initial_inventory","initial_inventory_kinds","initial_personal_stock")
  push!(scene[key],deepcopy(first(scene[key])))
 end
 push!(scene["positions"],[.7,6.])
 scene["initial_personal_food_counts"]["npc_e"]=zeros(Int,8)
 scene["personal_food_supply"]["npc_e"]=Dict("kind"=>1,"quantity"=>2)
 scene["peer_identity_roster"]["npc_e"]=Dict("name"=>"ソラ","features"=>[.21,.83,.52,.37,.68])
 input["config"]["mb_sensitivities"]["npc_e"]=deepcopy(input["config"]["mb_sensitivities"]["npc_b"])
 write(joinpath(OUTPUT,"source/src/data/lw_actor_ids.jl"),"const IDS=(\"npc_a\",\"npc_b\",\"npc_c\",\"npc_d\",\"npc_e\")\n")
end
write(joinpath(OUTPUT,"input.json"),JSON3.write(input))
if MODE=="join"
 daypath=joinpath(OUTPUT,"source/src/lw/simulation/day.jl")
 text=read(daypath,String)
 needle=LEARNED_CONTROL ? "saved=learned_channel_checkpoint(resume_from,checkpoint_identity,checkpoint_code,days)" : "saved=checkpoint_load(resume_from,checkpoint_identity,checkpoint_code,days)"
 @assert length(findall(needle,text))==1
 write(daypath,replace(text,needle=>"saved=cohort_join_checkpoint(resume_from,checkpoint_identity,checkpoint_code,days,@lw_capture())"))
 reportpath=joinpath(OUTPUT,"source/src/lw/simulation/integrated.jl")
 reporttext=read(reportpath,String)
 reportneedle="for n in r[\"daily\"]]"
 @assert length(findall(reportneedle,reporttext))==1
 write(reportpath,replace(reporttext,reportneedle=>"for n in r[\"daily\"] if haskey(n[\"sleep\"],a)]"))
end
if get(ENV,"RDL_WANT_AUDIT","0")=="1"
 include(joinpath(HERE,"want_audit_instrument.jl"))
 want_audit_instrument!(OUTPUT)
end
include(joinpath(OUTPUT,"source/integrations/lightweight_julia/native.jl"))
const LW=Main
include(joinpath(OUTPUT,"communication/trade_observation.jl"))
include(joinpath(OUTPUT,"communication/role_probe.jl"))
include(joinpath(OUTPUT,"communication/trade_channels.jl"))
const CHANNEL_MEMORIES=MODE=="train" ? Dict(a=>TradeChannelObserver() for a in IDS) : deserialize(joinpath(BASE,"communication_state.bin"))
MODE=="join" && (CHANNEL_MEMORIES["npc_e"]=TradeChannelObserver())
const CHANNELS=Dict("npc_a"=>(true,true),"npc_b"=>(true,false),"npc_c"=>(false,true),"npc_d"=>(false,false),"npc_e"=>(false,false))
include(joinpath(OUTPUT,"communication/alternate_vocabulary.jl"))
const ALTERNATE_E=get(ENV,"RDL_ALTERNATE_E","0")=="1"
ALTERNATE_E && (CHANNELS["npc_e"]=(true,true))
const NO_GESTURES=get(ENV,"RDL_NO_GESTURES","0")=="1"
if NO_GESTURES
 for actor in keys(CHANNELS)
  CHANNELS[actor]=(CHANNELS[actor][1],false)
 end
 @assert all(!channel[2] for channel in values(CHANNELS))
end
write(joinpath(OUTPUT,"channel_conditions.json"),JSON3.write((alternate_e=ALTERNATE_E,no_gestures=NO_GESTURES,channels=CHANNELS,e_words=ALTERNATE_E ? ALTERNATE_E_WORDS : nothing)))
LEARNED_CONTROL && include(joinpath(OUTPUT,"communication/learned_living.jl"))
if WANT_VOICE
 include(joinpath(OUTPUT,"communication/voice_dialogue.jl"))
 include(joinpath(OUTPUT,"communication/reply_trade.jl"))
 include(joinpath(OUTPUT,"communication/want_fish.jl"))
 include(joinpath(OUTPUT,"source/src/lw/configured_paths/voice_request.jl"))
 const WANT_VOICE_STATE=MODE!="train" && isfile(joinpath(BASE,"want_voice_state.bin")) ? deserialize(joinpath(BASE,"want_voice_state.bin")) : configured_want_state(IDS)
 if MODE=="join"
  WANT_VOICE_STATE["listeners"]["npc_e"]=VoiceListener("npc_e";seed=5,vocabulary=ObservedVocabulary())
 end
end
function live_channel_execute!(yaw,thinking,items,foods,w,stores,home,actor,op,action,now;kwargs...)
 observers=Dict(a=>(memory=CHANNEL_MEMORIES[a],yaw=yaw[a],attending=a in thinking) for a in IDS if a!=actor)
 speech,gesture=CHANNELS[actor]
 trade_channel_execute!(observers,items,foods,w,stores,home,actor,op,action,now;
  speech,gesture,spoken_words=ALTERNATE_E && actor=="npc_e" ? ALTERNATE_E_WORDS : nothing,actor_memory=CHANNEL_MEMORIES[actor],appearances=Dict(1=>"fruit-form",3=>"acorn-form",4=>"meal-form",8=>"fish-form"),kwargs...)
end
occursin("cohort_join_checkpoint",read(joinpath(OUTPUT,"source/src/lw/simulation/day.jl"),String)) && include(joinpath(OUTPUT,"communication/cohort_join.jl"))
arguments=[joinpath(OUTPUT,"run"),"--spec",joinpath(OUTPUT,"input.json"),"--checkpoint-dir",joinpath(OUTPUT,"checkpoints")]
MODE!="train" && append!(arguments,["--resume-from",joinpath(BASE,"checkpoints","day-"*lpad(STARTDAY,3,'0')*".jls")])
println("COHORT mode=$MODE start=$STARTDAY end=$(input["config"]["days"]) roster=$(IDS)")
elapsed=@elapsed native_main(arguments)
result=JSON3.read(read(joinpath(OUTPUT,"run/result.json"),String))
@test length(result.daily)==input["config"]["days"]
@test Set(String.(keys(result.final_agents)))==Set(IDS)
for day in result.daily
 @test result.initial_food+day.replenished_food==day.consumed+day.discarded_food+day.ground+day.shared_stock+sum(a.inventory+a.personal_stock for a in values(day.physical))
end
for a in IDS,k in (1,4,8)
 @test result.mb_map[Symbol(a)].food_taste_experiences[Symbol(food_taste_key(k,2))].samples>0
end
report=Dict(a=>Dict("events"=>length(m.processed),"episodes"=>length(m.roles.receipts),"words"=>m.words.evidence,
 "associations"=>[Dict("context"=>k[1],"token"=>k[2],"outcomes"=>v,"prediction"=>role_predict(m.roles,k...)) for (k,v) in m.roles.associations]) for (a,m) in CHANNEL_MEMORIES)
write(joinpath(OUTPUT,"communication_result.json"),JSON3.write(report))
LEARNED_CONTROL && write(joinpath(OUTPUT,"learned_control.json"),JSON3.write(LEARNED_CHANNEL_STATS))
serialize(joinpath(OUTPUT,"communication_state.bin"),CHANNEL_MEMORIES)
if WANT_VOICE
 serialize(joinpath(OUTPUT,"want_voice_state.bin"),WANT_VOICE_STATE)
 write(joinpath(OUTPUT,"want_voice_result.json"),JSON3.write((records=WANT_VOICE_STATE["records"],pending=collect(keys(WANT_VOICE_STATE["pending"])),days=length(result.daily))))
end
write(joinpath(OUTPUT,"completed.json"),JSON3.write((days=length(result.daily),start_day=STARTDAY,elapsed_seconds=elapsed,trade_counts=result.portable_items.counts)))
println("COMPLETED ",elapsed)
