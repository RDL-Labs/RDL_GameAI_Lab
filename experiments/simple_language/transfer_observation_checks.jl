include("../portable_items/checks.jl")
include("trade_observation.jl")
include("role_probe.jl")
include("trade_channels.jl")
@testset "Visible food movement, no unseen terms" begin
    f=item_fixture(objects=Any[],food_counts=[[2,0,0,0],[0,0,0,2],[0,0,0,0]])
    f.w.positions[ITEM_A]=(-.3,1.);f.w.positions[ITEM_B]=(.3,1.);f.w.positions[ITEM_C]=(0.,0.)
    appearances=Dict(1=>"shape-one",4=>"shape-four")
    offer=Dict("proposer"=>ITEM_A,"target"=>ITEM_B,"give_food"=>[1,0,0,0],"want_food"=>[0,0,0,1])
    observed=trade_visible_transfers(f.w,ITEM_C,0.,offer,appearances)
    @test length(observed)==2
    @test observed[1]==(from_visible_ref=ITEM_A,to_visible_ref=ITEM_B,appearance="shape-one",quantity=1)
    @test observed[2].to_visible_ref==ITEM_A
    @test isempty(trade_visible_transfers(f.w,ITEM_C,180.,offer,appearances))
    @test isempty(trade_visible_transfers(f.w,ITEM_C,0.,offer,appearances;attending=false))
    @test isempty(trade_visible_transfers(f.w,ITEM_C,0.,nothing,appearances))
    # Actual success closes the offer; duplicate operation must not teach twice.
    observer=TradeChannelObserver();observers=Dict(ITEM_C=>(memory=observer,yaw=0.,attending=true))
    result=trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_A,"visible-offer","item_offer",1;
        appearances,target=ITEM_B,give_food=[1,0,0,0],want_food=[0,0,0,1])
    accepted=trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_B,"visible-accept","item_accept",2;
        appearances,offer_id=result["offer_id"])
    @test accepted["status"]=="exchanged"
    receipt=observer.roles.receipts["visible-accept"]
    @test receipt[1].transfers==observed
    @test !occursin("own_before",JSON3.write(receipt[1]))
    @test !occursin("give_food",JSON3.write(receipt[1]))
    snapshot=deepcopy(observer.roles.receipts)
    trade_channel_execute!(observers,f.s,f.foods,f.w,f.stores,ITEM_HOME,ITEM_B,"visible-accept","item_accept",2;
        appearances,offer_id=result["offer_id"])
    @test observer.roles.receipts==snapshot
    @test item_checks(f)===nothing
end
