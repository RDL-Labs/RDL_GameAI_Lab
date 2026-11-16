include("../portable_items/checks.jl")
include("trade_observation.jl")
include("role_probe.jl")
include("trade_channels.jl")
include("alternate_vocabulary.jl")
@testset "different words shared gesture no translation" begin
 f=item_fixture(objects=Any[],food_counts=[[20,0,0,0],[0,0,0,20],[0,0,0,0]])
 f.w.positions[ITEM_A]=(-.3,1.);f.w.positions[ITEM_B]=(.3,1.);f.w.positions[ITEM_C]=(0.,0.)
 memory=TradeChannelObserver()
 observers=Dict(ITEM_C=>(memory=memory,yaw=0.,attending=true))
 @test isempty(memory.roles.receipts)
 offered=trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_A,"alternate-offer","item_offer",10;
  spoken_words=ALTERNATE_E_WORDS,target=ITEM_B,give_food=[1,0,0,0],want_food=[0,0,0,1])
 @test offered["status"]=="offered"
 observed=memory.pending[offered["offer_id"]][1]
 @test observed.text=="ナ"
 @test observed.motion=="present"
 @test isempty(memory.roles.receipts)
 result=trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_B,"alternate-accept","item_accept",11;
  spoken_words=ALTERNATE_E_WORDS,offer_id=offered["offer_id"])
 @test result["status"]=="exchanged"
 @test role_predict(memory.roles,"object-presented","ナ").samples==1
 @test role_predict(memory.roles,"object-presented","リ").samples==1
 @test role_predict(memory.roles,"object-presented","gesture:present").samples==1
 @test role_predict(memory.roles,"object-presented","モ").samples==0
 @test item_checks(f)===nothing
end
