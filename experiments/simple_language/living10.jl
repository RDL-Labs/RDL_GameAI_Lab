# Isolated opt-in life-loop bridge. Fixed expression assignment, no forced trades.
using JSON3,Test,Serialization
length(ARGS)==1 || error("usage: living10.jl NEW_OUTPUT")
const OUTPUT=abspath(only(ARGS));ispath(OUTPUT) && error("fresh output required")
const REPO=normpath(joinpath(@__DIR__,"../.."))
mkpath(OUTPUT);mkpath(joinpath(OUTPUT,"source/integrations"))
cp(joinpath(REPO,"src"),joinpath(OUTPUT,"source/src"))
cp(joinpath(REPO,"integrations/lightweight_julia"),joinpath(OUTPUT,"source/integrations/lightweight_julia"))
cp(@__DIR__,joinpath(OUTPUT,"communication"))
input=JSON3.read(read(joinpath(REPO,"experiments/trade_living/tasting30_input.json"),String),Dict{String,Any})
input["config"]["days"]=13 # three actual tasting days, then ten living days
write(joinpath(OUTPUT,"input.json"),JSON3.write(input))
write(joinpath(OUTPUT,"source/src/data/lw_actor_ids.jl"),"const IDS=(\"npc_a\",\"npc_b\",\"npc_c\",\"npc_d\")\n")
daypath=joinpath(OUTPUT,"source/src/lw/simulation/day.jl")
daytext=read(daypath,String)
needle="receipt=item_execute!(items,shared_stores ? nothing : foods,w,stores,spec.home,a,op,action,now;"
@assert length(findall(needle,daytext))==1
write(daypath,replace(daytext,needle=>"receipt=live_channel_execute!(yaw,thinking_ids,items,shared_stores ? nothing : foods,w,stores,spec.home,a,op,action,now;"))
include(joinpath(OUTPUT,"source/integrations/lightweight_julia/native.jl"))
const LW=Main
include(joinpath(OUTPUT,"communication/trade_observation.jl"))
include(joinpath(OUTPUT,"communication/role_probe.jl"))
include(joinpath(OUTPUT,"communication/trade_channels.jl"))
const CHANNEL_MEMORIES=Dict(a=>TradeChannelObserver() for a in IDS)
# 暫定固定: A speech+gesture, B speech, C gesture, D neither. All start unknown.
# Thinking actors observe incidentally in current FOV; no forced gaze or wakeup.
const CHANNELS=Dict("npc_a"=>(true,true),"npc_b"=>(true,false),"npc_c"=>(false,true),"npc_d"=>(false,false))
function live_channel_execute!(yaw,thinking,items,foods,w,stores,home,actor,op,action,now;kwargs...)
    observers=Dict(a=>(memory=CHANNEL_MEMORIES[a],yaw=yaw[a],attending=a in thinking) for a in IDS if a!=actor)
    speech,gesture=CHANNELS[actor]
    trade_channel_execute!(observers,items,foods,w,stores,home,actor,op,action,now;
        speech,gesture,appearances=Dict(1=>"fruit-form",3=>"acorn-form",4=>"meal-form",8=>"fish-form"),kwargs...)
end
println("CONDITIONS: tasting3 + living10; human4; individual supply; no animals/forage; A both B speech C gesture D neither; fixed production; observation only; no learned control")
elapsed=@elapsed native_main([joinpath(OUTPUT,"run"),"--spec",joinpath(OUTPUT,"input.json"),"--checkpoint-dir",joinpath(OUTPUT,"checkpoints")])
result=JSON3.read(read(joinpath(OUTPUT,"run/result.json"),String))
@test length(result.daily)==13
@test result.replenished_food==104
for day in result.daily
 @test result.initial_food+day.replenished_food==day.consumed+day.discarded_food+day.ground+day.shared_stock+sum(a.inventory+a.personal_stock for a in values(day.physical))
end
report=Dict(a=>Dict("events"=>length(m.processed),"episodes"=>length(m.roles.receipts),"words"=>m.words.evidence,
 "associations"=>[Dict("context"=>k[1],"token"=>k[2],"outcomes"=>v,"prediction"=>role_predict(m.roles,k...)) for (k,v) in m.roles.associations]) for (a,m) in CHANNEL_MEMORIES)
write(joinpath(OUTPUT,"communication_result.json"),JSON3.write(report))
serialize(joinpath(OUTPUT,"communication_state.bin"),CHANNEL_MEMORIES)
write(joinpath(OUTPUT,"completed.json"),JSON3.write((days=13,living_days=10,elapsed_seconds=elapsed,trade_counts=result.portable_items.counts)))
println("COMPLETED ",elapsed)
