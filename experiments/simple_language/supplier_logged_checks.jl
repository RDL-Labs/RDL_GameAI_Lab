using Test,JSON3,Serialization
const LOCAL_SOURCE=mktempdir()
cp("C:/Users/ken_m/Documents/Codex/communication-private-supplier60-20261119/source",joinpath(LOCAL_SOURCE,"source"))
cp(joinpath(@__DIR__,"../../src/lw/decision/item_social.jl"),joinpath(LOCAL_SOURCE,"source/src/lw/decision/item_social.jl");force=true)
include(joinpath(LOCAL_SOURCE,"source/integrations/lightweight_julia/native.jl"))
const LW=Main
include("trade_observation.jl")
include("voice_dialogue.jl")
include("reply_trade.jl")
include("want_fish.jl")
include("../../src/lw/configured_paths/voice_request.jl")
const CHANNELS=Dict(a=>(true,true) for a in ("npc_a","npc_b","npc_c","npc_d","npc_e"))
learned_channel_plan!(args...;kwargs...)=item_social_plan!(args...;kwargs...)
const ROOT="C:/Users/ken_m/Documents/Codex/communication-private-supplier60-20261119"
const INPUT=JSON3.read(read(joinpath(ROOT,"input.json"),String),Dict{String,Any})
records=JSON3.read(read(joinpath(ROOT,"want_voice_result.json"),String),Dict{String,Any})["records"]
report=Any[]
@testset "logged interested replies create supplier decisions" begin
 for (day,now) in ((40,673982000000),(56,950462000000))
  @test any(r->r["event"]=="reply" && r["actor"]=="npc_d" && r["caller"]=="npc_b" && r["us"]==now && r["interested"],records)
  saved=deserialize(joinpath(ROOT,"checkpoints","day-"*lpad(day-1,3,'0')*".jls")).state
  outcomes=Any[]
  for enabled in (false,true)
   s=deepcopy(saved);a="npc_d";b="npc_b"
   configured_personal_food_supply!(s[:foods],s[:stores],s[:replenishments],INPUT["scene"]["personal_food_supply"],day-1,(day-1)*17_280_000_000)
   state=s[:incidental_items][a];mind=item_social_state!(state)
   # Same local admission in both variants; isolate the connection, not timing.
   mind["next_us"]=now
   view=item_visible(s[:items],s[:w],(0.,6.),a,s[:yaw][a],now;foods=s[:foods],open_stores=false,illumination=1.)
   @test b in view["trade_partners"]
   @test !haskey(view,"observed_food_stocks")
   before=(candidates=mind["candidates"],decisions=mind["decisions"])
   supply=(partner=b,kind=8,known_kinds=configured_want_recall(s[:mb_maps][a]))
   voice=configured_want_state(keys(s[:w].positions))
   if enabled
    voice["supply_requests"]=D(a=>(partner=b,kind=8,expires=now+6_000_000,call_id="logged:$day"))
    plan=configured_want_plan!(voice,17_280_000_000,state,view,s[:w].bodies[a],s[:guts]===nothing ? nothing : s[:guts][a],s[:foods].personal[a],now;
       map=s[:mb_maps][a],relation=s[:relations][a])
   else
    plan=item_social_plan!(state,view,s[:w].bodies[a],s[:guts]===nothing ? nothing : s[:guts][a],s[:foods].personal[a],now;map=s[:mb_maps][a],relation=s[:relations][a])
   end
   row=D("enabled"=>enabled,"stock"=>copy(s[:foods].personal[a]),"candidates"=>mind["candidates"]-before.candidates,
         "decisions"=>mind["decisions"]-before.decisions,"action"=>plan===nothing ? nothing : plan["action"])
   row["evaluation"]=get(state,"last_supply_evaluation",nothing)
   if plan!==nothing
    @test plan["target"]==b
    @test all(plan["give_food"].<=s[:foods].personal[a])
    row["give"]=plan["give_food"];row["ask"]=plan["want_food"]
    receipt=item_execute!(s[:items],s[:foods],s[:w],s[:stores],(0.,6.),a,"local:$day",plan["action"],now;
      target=b,give_food=plan["give_food"],want_food=plan["want_food"],give_items=plan["give_items"],want_items=plan["want_items"])
    @test receipt["status"]=="offered"
    row["execution"]=receipt["status"]
   end
   push!(outcomes,row)
  end
  @test outcomes[1]["decisions"]==0
  println(JSON3.write((day=day,outcomes=outcomes)))
  @test outcomes[2]["evaluation"]["evaluated"]>0
  push!(report,D("day"=>day,"basis"=>"previous day-end state + configured next-day supply + logged request; not exact tick replay","variants"=>outcomes))
 end
end
write("C:/Users/ken_m/Documents/Codex/private-supplier-local40-56.json",JSON3.write(report))
println(JSON3.write(report))
