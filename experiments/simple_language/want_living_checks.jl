include("want_fish_checks.jl")
const D=LW.D
const food_security=LW.food_security
const configured_peer_identity_memory=LW.configured_peer_identity_memory
const item_social_state! = LW.item_social_state!
const CHANNELS=Dict(ITEM_A=>(true,true),ITEM_B=>(true,false),ITEM_C=>(false,true))
learned_channel_plan!(args...;kwargs...)=LW.item_social_plan!(args...;kwargs...)
include("../../src/lw/configured_paths/voice_request.jl")
living_proposals=0
@testset "scheduled request reply and trade bridge" begin
 for seed in 1:32
  f=want_fixture();voice=configured_want_state((ITEM_A,ITEM_B,ITEM_C))
  voice["listeners"][ITEM_B]=VoiceListener(ITEM_B;seed,vocabulary=want_fish_vocabulary())
  relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in (ITEM_A,ITEM_B,ITEM_C))
  state=LW.incidental_item_state(ITEM_A,seed);headings=Dict(ITEM_A=>0.,ITEM_B=>180.,ITEM_C=>270.)
  p=configured_want_plan!(voice,17_280_000_000,state,item_view(f,ITEM_A;open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0;relation=relations[ITEM_A])
  @test p["method"]=="voice_request_call"
  configured_want_tick!(voice,f.w,headings,String[],f.foods,relations,WANT_ROSTER,500_000)
  @test length(voice["records"])==1 # no sleeping/occupied listeners woken
  for now in (1_000_000,2_000_000)
   configured_want_tick!(voice,f.w,headings,[ITEM_A,ITEM_B,ITEM_C],f.foods,relations,WANT_ROSTER,now)
  end
  p=configured_want_plan!(voice,17_280_000_000,state,item_view(f,ITEM_A;now=2_000_000,open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],2_000_000;relation=relations[ITEM_A])
  if p!==nothing && p["action"]=="item_offer"
   global living_proposals+=1
   @test p["target"]==ITEM_B && p["want_food"][WANT_FISH.kind]>0
   @test reply_trade_execute!(f,ITEM_A,state,relations[ITEM_A],p,2_000_000)["status"]=="offered"
   @test any(r->r["source"]==p["source"],relations[ITEM_A]["gradient_maps"]["records"])
   @test relations[ITEM_A]["use_counts"]["trade_offer"]>0
  end
  configured_want_tick!(voice,f.w,headings,[ITEM_A,ITEM_B,ITEM_C],f.foods,relations,WANT_ROSTER,8_000_000)
  @test isempty(voice["pending"])
  @test item_checks(f)===nothing
 end
 @test living_proposals>0
end
println("living request proposals=",living_proposals)
