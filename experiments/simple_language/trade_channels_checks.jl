include("../portable_items/checks.jl")
include("trade_observation.jl")
include("role_probe.jl")
include("trade_channels.jl")
rows=Any[]
@testset "actual trade APIs with optional communication channels" begin
 for (speech,gesture) in ((true,true),(true,false),(false,true),(false,false))
  f=item_fixture(objects=Any[],food_counts=[[20,0,0,0],[0,0,0,20],[0,0,0,0]])
  f.w.positions[ITEM_A]=(-.3,1.);f.w.positions[ITEM_B]=(.3,1.);f.w.positions[ITEM_C]=(0.,0.)
  memory=TradeChannelObserver()
  observers=Dict(ITEM_C=>(memory=memory,yaw=0.,attending=true))
  for i in 1:4
   offered=trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_A,"offer$i","item_offer",i*10;
    speech,gesture,appearances=Dict(1=>"round-red"),target=ITEM_B,give_food=[1,0,0,0],want_food=[0,0,0,1])
   @test offered["status"]=="offered"
   action=i<=2 ? "item_accept" : "item_decline"
   result=trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_B,"reply$i",action,i*10+1;
    speech,gesture,offer_id=offered["offer_id"])
   @test result["status"]==(i<=2 ? "exchanged" : "declined")
   snapshot=deepcopy(memory.roles.associations)
   @test trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_B,"reply$i",action,i*10+1;
    speech,gesture,offer_id=offered["offer_id"])==result
   @test memory.roles.associations==snapshot
  end
  @test f.foods.personal[ITEM_A][4]==2 && f.foods.personal[ITEM_B][1]==2
  @test item_checks(f)===nothing
  @test isempty(memory.pending)
  for (enabled,token) in ((speech,"ユ"),(gesture,"gesture:release"))
   @test role_predict(memory.roles,"object-presented",token).status==(enabled ? "provisional" : "unknown")
  end
  if speech
   @test role_predict(memory.roles,"object-presented","ケ").predicted=="object-withdrawn"
   @test role_predict(memory.roles,"object-presented","モ").status=="ambiguous"
  end
  push!(rows,(speech=speech,gesture=gesture,accept_word=role_predict(memory.roles,"object-presented","ユ"),
    accept_gesture=role_predict(memory.roles,"object-presented","gesture:release")))
 end
end
write(joinpath(@__DIR__,"trade_channels_result.json"),JSON3.write(rows))
