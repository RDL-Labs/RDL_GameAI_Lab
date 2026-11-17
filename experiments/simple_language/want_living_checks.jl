include("want_fish_checks.jl")
const D=LW.D
const food_security=LW.food_security
const configured_peer_identity_memory=LW.configured_peer_identity_memory
const item_social_state! = LW.item_social_state!
const CHANNELS=Dict(ITEM_A=>(true,true),ITEM_B=>(true,false),ITEM_C=>(false,true))
learned_channel_plan!(args...;kwargs...)=LW.item_social_plan!(args...;kwargs...)
include("../../src/lw/configured_paths/voice_request.jl")
function request_test_map()
 map=D(); for kind in (1,4,8); LW.food_remember_taste!(map,kind,2,.5,0); end; map
end
living_proposals=0
@testset "scheduled request reply and trade bridge" begin
 for seed in 1:32
  f=want_fixture(peer_stock=fill(20,8));voice=configured_want_state((ITEM_A,ITEM_B,ITEM_C))
  voice["listeners"][ITEM_B]=VoiceListener(ITEM_B;seed,vocabulary=configured_want_vocabulary())
  relations=Dict(a=>LW.social_relations_state(a;relational=true) for a in (ITEM_A,ITEM_B,ITEM_C))
  state=LW.incidental_item_state(ITEM_A,seed);headings=Dict(ITEM_A=>0.,ITEM_B=>180.,ITEM_C=>270.)
  p=configured_want_plan!(voice,17_280_000_000,state,item_view(f,ITEM_A;open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0;relation=relations[ITEM_A],map=request_test_map())
  @test p["method"]=="voice_request_call"
  requested_kind=voice["pending"][ITEM_A]["requested_food"]
  @test voice["pending"][ITEM_A]["event"].text==CONFIGURED_WANT_WORDS[requested_kind]*" 欲しい"
  configured_want_tick!(voice,f.w,headings,String[],f.foods,relations,WANT_ROSTER,500_000)
  @test length(voice["records"])==1 # no sleeping/occupied listeners woken
  for now in (1_000_000,2_000_000)
   configured_want_tick!(voice,f.w,headings,[ITEM_A,ITEM_B,ITEM_C],f.foods,relations,WANT_ROSTER,now)
  end
  p=configured_want_plan!(voice,17_280_000_000,state,item_view(f,ITEM_A;now=2_000_000,open_stores=true),f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],2_000_000;relation=relations[ITEM_A],map=request_test_map())
  if p!==nothing && p["action"]=="item_offer"
   global living_proposals+=1
   @test p["target"]==ITEM_B && p["want_food"][requested_kind]>p["give_food"][requested_kind]
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
@testset "food knowledge requires eating evidence" begin
 f=want_fixture();body=f.w.bodies[ITEM_A];stock=zeros(Int,8)
 @test configured_want_desire(body,nothing,stock;map=D())===nothing
 map=request_test_map()
 @test !configured_want_known_food(map,2)
 @test configured_want_desire(body,nothing,stock;map).kind in (1,4,8)
 maps=Dict(a=>D() for a in (ITEM_A,ITEM_B,ITEM_C))
 # B is in front of A; facing B sees the meal, facing away does not.
 away=Dict(ITEM_A=>LW.social_sight(f.w,ITEM_A,180.,0;illumination=1.))
 configured_want_observe_meal!(maps,away,ITEM_B,2,0)
 @test !configured_want_known_food(maps[ITEM_A],2)
 sight=Dict(ITEM_A=>LW.social_sight(f.w,ITEM_A,0.,0;illumination=1.))
 configured_want_observe_meal!(maps,sight,ITEM_B,2,1) # stale observation
 @test !configured_want_known_food(maps[ITEM_A],2)
 configured_want_observe_meal!(maps,sight,ITEM_B,2,0)
 @test configured_want_known_food(maps[ITEM_A],2)
 @test !haskey(maps[ITEM_A],"food_taste_experiences")
 @test !configured_want_known_food(maps[ITEM_C],2) # not attending
 @test configured_want_desire(body,nothing,stock;map=maps[ITEM_A]).kind==2
end
println("living request proposals=",living_proposals)
@testset "request subject follows own marginal food desire" begin
 f=want_fixture();body=f.w.bodies[ITEM_A]
 fruit_stock=fill(10_000,8);fruit_stock[1]=0
 fish_stock=fill(10_000,8);fish_stock[8]=0
 @test configured_want_desire(body,nothing,fruit_stock;map=request_test_map()).kind==1
 @test configured_want_desire(body,nothing,fish_stock;map=request_test_map()).kind==8
 @test configured_want_desire(body,nothing,nothing)===nothing
 voice=configured_want_state((ITEM_A,ITEM_B,ITEM_C))
 state=LW.incidental_item_state(ITEM_A,1)
 configured_want_plan!(voice,17_280_000_000,state,item_view(f,ITEM_A;open_stores=true),body,nothing,fruit_stock,0;map=request_test_map())
 @test voice["pending"][ITEM_A]["requested_food"]==1
 @test voice["pending"][ITEM_A]["event"].text=="果実 欲しい"
 @test voice["records"][end]["gradient"]["total"]>0
end
