using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
const D=LW.D
function camp_fixture(seed=1)
    w=LW.world(true);ids=collect(LW.IDS)
    for a in ids;w.positions[a]=(0.,0.);w.inventory[a]=0;w.bodies[a]=LW.RDLBody.Body(10.,0.,100.,0.);end
    counts=Dict(Symbol(a)=>[k==(i==1 ? 7 : 1) && i!=3 ? 8 : 0 for k in 1:8] for (i,a) in enumerate(ids))
    stores=Dict(a=>sum(counts[Symbol(a)]) for a in ids)
    spec=(typed_food=true,initial_personal_food_counts=counts,portable_items=Any[])
    foods=LW.food_resources(spec,w,Any[],Int[],0,stores);items=LW.portable_items(spec,w)
    states=Dict(a=>LW.incidental_item_state(a,seed) for a in ids);maps=Dict(a=>D() for a in ids)
    for a in ids, k in (1,7);LW.food_remember_taste!(maps[a],k,2,.5,0);end
    (w=w,foods=foods,items=items,stores=stores,states=states,maps=maps,ids=ids)
end

module VoiceRecallCompatibility
import Main: LW
include("../../src/lw/configured_paths/voice_request.jl")
end
@testset "existing voice request uses owner desire" begin
    f=camp_fixture();a=first(f.ids)
    fruit_stock=fill(10_000,8);fruit_stock[1]=0
    fish_stock=fill(10_000,8);fish_stock[7]=0
    @test VoiceRecallCompatibility.configured_want_desire(f.w.bodies[a],nothing,fruit_stock;map=f.maps[a]).kind==1
    @test VoiceRecallCompatibility.configured_want_desire(f.w.bodies[a],nothing,fish_stock;map=f.maps[a]).kind==7
    @test VoiceRecallCompatibility.configured_want_desire(f.w.bodies[a],nothing,fish_stock;map=D())===nothing
    @test VoiceRecallCompatibility.configured_want_desire(f.w.bodies[a],nothing,nothing)===nothing
end
camp_tick(f,now;sleeping=a->false)=LW.configured_camp_trade_tick!(f.states,f.maps,f.w,f.foods,nothing,nothing,now,a->true,sleeping,a->false)
function camp_event(f)
    a=first(f.ids)
    LW.configured_camp_trade_call!(f.states[a],f.maps[a],f.w.bodies[a],nothing,f.foods.personal[a],0,1_000_000_000)
end
@testset "private camp call and attention" begin
    f=camp_fixture();a,b,c=f.ids
    @test LW.trade_request_desire(f.w.bodies[a],nothing,f.foods.personal[a];map=D())===nothing
    event=camp_event(f)
    @test event["kind"]==1
    @test event["addressee"]===nothing
    @test event["offered"]==Dict(7=>1)
    f.w.positions[b]=(5.,0.) # Beyond old contact range, still inside declared camp.
    camp_tick(f,1_000_000)
    @test LW.configured_camp_trade_state!(f.states[b])["heard"]==1
    @test LW.configured_camp_trade_state!(f.states[c])["heard"]==1
    @test LW.configured_camp_trade_state!(f.states[b])["replied"]==1
    @test !LW.configured_camp_trade_busy(f.states[c])
    @test LW.configured_camp_trade_busy(f.states[b])
    camp_tick(f,2_000_000)
    @test LW.configured_camp_trade_state!(f.states[b])["heard"]==1
    raw=LW.item_visible(f.items,f.w,(0.,0.),a,0.,2_000_000;foods=f.foods)
    observed=LW.configured_camp_trade_view(f.states[a],raw,2_000_000)
    @test !haskey(raw,"observed_food_stocks") && !haskey(raw,"announced_food_offers")
    @test LW.observed_food_count(observed,b,1)==1
    @test LW.observed_food_count(observed,b,7)===nothing
    @test f.foods.personal[b][1]==8 # Announced quantity is NOT full stock.
    @test !haskey(LW.configured_camp_trade_view(f.states[a],raw,200_000_000),"announced_food_offers")
    f2=camp_fixture();camp_event(f2);camp_tick(f2,1_000_000;sleeping=x->x==b)
    @test LW.configured_camp_trade_state!(f2.states[b])["sleep_ignored"]==1
    @test !LW.configured_camp_trade_busy(f2.states[b])
    io=IOBuffer();serialize(io,f);seekstart(io);restored=deserialize(io)
    @test LW.configured_camp_trade_state!(restored.states[a])["meeting"]==LW.configured_camp_trade_state!(f.states[a])["meeting"]
end

successful=nothing;exchanges=0
@testset "announced food reaches ordinary negotiation and learning" begin
    for seed in 1:32
        f=camp_fixture(seed);a,b,c=f.ids;camp_event(f);camp_tick(f,1_000_000)
        view=LW.configured_camp_trade_view(f.states[a],LW.item_visible(f.items,f.w,(0.,0.),a,0.,2_000_000;foods=f.foods),2_000_000)
        plan=LW.configured_camp_trade_plan!(f.states[a],view,f.w.bodies[a],nothing,f.foods.personal[a],2_000_000;map=f.maps[a])
        plan===nothing && continue
        @test plan["action"]=="item_offer"
        receipt=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),a,"offer:$seed","item_offer",2_000_000;
            target=b,give_items=plan["give_items"],want_items=plan["want_items"],give_food=plan["give_food"],want_food=plan["want_food"])
        @test receipt["status"]=="offered"
        LW.item_social_executed!(f.states[a],plan,receipt)
        reply_view=LW.item_visible(f.items,f.w,(0.,0.),b,0.,3_000_000;foods=f.foods)
        response=LW.item_social_plan!(f.states[b],reply_view,f.w.bodies[b],nothing,f.foods.personal[b],3_000_000;map=f.maps[b])
        response===nothing && continue
        outcome=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),b,"response:$seed",response["action"],3_000_000;offer_id=response["offer_id"],
            give_items=get(response,"give_items",Int[]),want_items=get(response,"want_items",Int[]),give_food=get(response,"give_food",zeros(Int,8)),want_food=get(response,"want_food",zeros(Int,8)))
        LW.item_social_executed!(f.states[b],response,outcome)
        LW.item_social_observe!(f.states[a],LW.item_visible(f.items,f.w,(0.,0.),a,0.,4_000_000;foods=f.foods))
        if outcome["status"]=="exchanged"
            global exchanges+=1;global successful=f
            @test sum(sum(v) for v in values(f.foods.personal))==16
            @test f.foods.personal[a][1]>0 && f.foods.personal[b][7]>0
        end
    end
    @test exchanges>0
    if successful!==nothing
        f=successful;a,b,c=f.ids
        address=LW.configured_camp_trade_address!(f.states[a],1,9_000_000)
        @test address.support[b]>0
        @test address.probabilities[b]>address.probabilities["broadcast"]
        @test !haskey(address.probabilities,c)
        @test isempty(LW.item_exchange_supplier_support(f.states[a],7,[b]))
        println(JSON3.write((successful_seeds=exchanges,total_seeds=32,address=address)))
    end
end

@testset "simultaneous calls do not mutually block" begin
    f=camp_fixture();a,b,c=f.ids;camp_event(f)
    @test LW.configured_camp_trade_call!(f.states[b],f.maps[b],f.w.bodies[b],nothing,f.foods.personal[b],0,1_000_000_000)!==nothing
    camp_tick(f,1_000_000)
    @test f.states[a]["camp_trade"]["meeting"]["peer"]==b
    @test f.states[b]["camp_trade"]["meeting"]["peer"]==a
    @test f.states[b]["camp_trade"]["outgoing"]===nothing
    LW.configured_camp_trade_result!(f.states,a,D("status"=>"declined"),2_000_000)
    @test !LW.configured_camp_trade_busy(f.states[a]) && !LW.configured_camp_trade_busy(f.states[b])
end
