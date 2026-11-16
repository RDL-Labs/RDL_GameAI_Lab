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
if LEARNED_CONTROL
 for file in ("item_social.jl","gradient_trace.jl","trade_communication.jl")
  cp(joinpath(HERE,"../../src/lw/decision",file),joinpath(OUTPUT,"source/src/lw/decision",file);force=true)
 end
 daypath=joinpath(OUTPUT,"source/src/lw/simulation/day.jl")
 daytext=read(daypath,String)
 daytext=replace(daytext,"plan=item_social_plan!("=>"plan=learned_channel_plan!(")
 MODE=="continue" && (daytext=replace(daytext,"saved=checkpoint_load(resume_from,checkpoint_identity,checkpoint_code,days)"=>"saved=learned_channel_checkpoint(resume_from,checkpoint_identity,checkpoint_code,days)"))
 write(daypath,daytext)
end
input=JSON3.read(read(joinpath(BASE,"input.json"),String),Dict{String,Any})
const STARTDAY=MODE=="train" ? 0 : Int(JSON3.read(read(joinpath(BASE,"completed.json"),String)).days)
input["config"]["days"]=MODE=="train" ? 3 : STARTDAY+20
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
include(joinpath(OUTPUT,"source/integrations/lightweight_julia/native.jl"))
const LW=Main
include(joinpath(OUTPUT,"communication/trade_observation.jl"))
include(joinpath(OUTPUT,"communication/role_probe.jl"))
include(joinpath(OUTPUT,"communication/trade_channels.jl"))
const CHANNEL_MEMORIES=MODE=="train" ? Dict(a=>TradeChannelObserver() for a in IDS) : deserialize(joinpath(BASE,"communication_state.bin"))
MODE=="join" && (CHANNEL_MEMORIES["npc_e"]=TradeChannelObserver())
const CHANNELS=Dict("npc_a"=>(true,true),"npc_b"=>(true,false),"npc_c"=>(false,true),"npc_d"=>(false,false),"npc_e"=>(false,false))
LEARNED_CONTROL && include(joinpath(OUTPUT,"communication/learned_living.jl"))
function live_channel_execute!(yaw,thinking,items,foods,w,stores,home,actor,op,action,now;kwargs...)
 observers=Dict(a=>(memory=CHANNEL_MEMORIES[a],yaw=yaw[a],attending=a in thinking) for a in IDS if a!=actor)
 speech,gesture=CHANNELS[actor]
 trade_channel_execute!(observers,items,foods,w,stores,home,actor,op,action,now;
  speech,gesture,actor_memory=CHANNEL_MEMORIES[actor],appearances=Dict(1=>"fruit-form",3=>"acorn-form",4=>"meal-form",8=>"fish-form"),kwargs...)
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
write(joinpath(OUTPUT,"completed.json"),JSON3.write((days=length(result.daily),start_day=STARTDAY,elapsed_seconds=elapsed,trade_counts=result.portable_items.counts)))
println("COMPLETED ",elapsed)
