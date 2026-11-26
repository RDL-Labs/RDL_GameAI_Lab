include("camp_trade_calls_checks.jl")
const PROCESSING_FACILITIES=[(id=1,x=0.,z=0.,work_radius=2.,height=1.,radius=.5,color="brown",processing_kinds=[5])]
function processing_fixture(seed=1;caller_cooks=false,supplier_cooks=true)
    f=camp_fixture(seed);a,b,c=f.ids
    for actor in f.ids;fill!(f.foods.personal[actor],0);empty!(f.maps[actor]);end
    f.foods.personal[a][1]=8;f.foods.personal[b][5]=8
    for actor in f.ids
        f.stores[actor]=sum(f.foods.personal[actor])
        for k in (1,5,7);LW.food_remember_taste!(f.maps[actor],k,2,k==5 ? -.8 : .5,0);end
    end
    LW.food_remaining!(f.foods,Int[]);f.foods.initial.=f.foods.scratch
    kitchen(actor)=(;actor,foods=f.foods,facilities=(actor==a ? caller_cooks : supplier_cooks) ? PROCESSING_FACILITIES : [],position=f.w.positions[actor],processing=true)
    # The case under test explicitly requests cooked fish. Desire selection is
    # tested separately; a capable actor may otherwise request raw fish directly.
    event=D("id"=>"fixture:cooked-request","caller"=>a,"kind"=>7,"offered"=>Dict(1=>1),
        "created_us"=>0,"expires_us"=>LW.CAMP_TRADE_CALL_RULES.lifetime_us,"addressee"=>nothing,
        "expected_reply"=>0.,"heard"=>Set{String}(),"replies"=>Any[],
        "processing_inputs"=>LW.trade_request_processing_inputs(f.maps[a],f.w.bodies[a],nothing,kitchen(a),7))
    channel=LW.configured_camp_trade_state!(f.states[a]);channel["outgoing"]=event;channel["calls"]=1;channel["last_day"]=0
    (;f...,kitchen,event)
end
function processing_tick(f,now)
    LW.configured_camp_trade_tick!(f.states,f.maps,f.w,f.foods,nothing,nothing,now,a->true,a->false,a->false;kitchen_for=f.kitchen,processing_requests=true,items=f.items)
end
function prepare_supplier!(f,actor,now)
    ticks=0
    while true
        plan=LW.configured_camp_processing_plan(f.states[actor],f.maps[actor],f.w.bodies[actor],nothing,f.kitchen(actor),now;items=f.items,at_home=true)
        plan===nothing && break
        ticks+=1;ticks<=122 || error("preparation did not terminate")
        action=plan["action"]
        if action=="retrieve"
            LW.food_retrieve!(f.foods,actor,false,nothing,LW.body_energy(f.w.bodies[actor]);kind=plan["food_kind"])
            f.stores[actor]-=1;f.w.inventory[actor]+=1
        elseif action=="process_food"
            LW.food_facility_for(f.kitchen(actor).facilities,f.w.positions[actor],plan["food_kind"])!==nothing || error("missing facility")
            f.w.bodies[actor],status,_,_=LW.step(f.w.bodies[actor],action,f.w.inventory[actor])
            status=="worked" || error("body could not process")
            LW.food_process!(f.foods,actor;kind=plan["food_kind"],salt_id=plan["salt_id"],items=f.items,now)
        elseif action=="unload"
            f.stores[actor]+=f.w.inventory[actor];f.w.inventory[actor]=0
            LW.food_deposit!(f.foods,actor,false)
        end
        now+=1_000_000
    end
    LW.food_audit!(f.foods,f.w,Int[],0,f.stores)
    (now,ticks)
end
function negotiate_processing!(f,now)
    a,b,c=f.ids
    raw=LW.item_visible(f.items,f.w,(0.,0.),a,0.,now;foods=f.foods)
    view=LW.configured_camp_trade_view(f.states[a],raw,now)
    plan=LW.configured_camp_trade_plan!(f.states[a],view,f.w.bodies[a],nothing,f.foods.personal[a],now;map=f.maps[a],kitchen=f.kitchen(a))
    plan===nothing && return false
    receipt=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),a,"offer:$now","item_offer",now;
        target=b,give_items=plan["give_items"],want_items=plan["want_items"],give_food=plan["give_food"],want_food=plan["want_food"])
    @test receipt["status"]=="offered"
    LW.item_social_executed!(f.states[a],plan,receipt)
    view_b=LW.configured_camp_trade_view(f.states[b],LW.item_visible(f.items,f.w,(0.,0.),b,0.,now+1_000_000;foods=f.foods),now+1_000_000)
    response=LW.configured_camp_trade_plan!(f.states[b],view_b,f.w.bodies[b],nothing,f.foods.personal[b],now+1_000_000;map=f.maps[b],kitchen=f.kitchen(b))
    response===nothing && return false
    outcome=LW.item_execute!(f.items,f.foods,f.w,f.stores,(0.,0.),b,"reply:$now",response["action"],now+1_000_000;offer_id=response["offer_id"],target=get(response,"target",nothing),
        give_items=get(response,"give_items",Int[]),want_items=get(response,"want_items",Int[]),give_food=get(response,"give_food",zeros(Int,8)),want_food=get(response,"want_food",zeros(Int,8)))
    LW.item_social_executed!(f.states[b],response,outcome)
    LW.item_social_observe!(f.states[a],LW.item_visible(f.items,f.w,(0.,0.),a,0.,now+2_000_000;foods=f.foods))
    LW.food_audit!(f.foods,f.w,Int[],0,f.stores)
    outcome["status"]=="exchanged"
end
@testset "processing reply boundary" begin
    f=processing_fixture(supplier_cooks=false);a,b,c=f.ids
    processing_tick(f,1_000_000)
    @test f.states[b]["camp_trade"]["replied"]==0
    f=processing_fixture();a,b,c=f.ids
    @test LW.configured_camp_trade_interest(f.event,f.states[b],f.maps[b],f.w.bodies[b],nothing,f.foods.personal[b],1;kitchen=f.kitchen(b))===nothing # default remains OFF
    processing_tick(f,1_000_000)
    @test f.states[b]["camp_trade"]["replied"]==1
    @test f.states[b]["camp_trade"]["meeting"]["preparation"]["mode"]=="supplier_processing"
    @test f.states[b]["camp_trade"]["records"][1]["gradient"]["processing_cost"]<0
    @test f.foods.personal[b][7]==0
    @test isempty(f.states[a]["camp_trade"]["meeting"]["announced"])
    @test !negotiate_processing!(f,2_000_000)
    io=IOBuffer();serialize(io,f.states);seekstart(io)
    @test deserialize(io)[b]["camp_trade"]["meeting"]==f.states[b]["camp_trade"]["meeting"]
    # No salt: neither actor can claim the salt-grilled result.
    for actor in (a,b);LW.food_remember_taste!(f.maps[actor],8,2,.8,0);end
    @test LW.trade_request_processing(f.maps[b],f.w.bodies[b],nothing,f.kitchen(b),5,8;items=f.items)===nothing
    @test LW.trade_request_processing(D(),f.w.bodies[b],nothing,f.kitchen(b),5,7;items=f.items)===nothing
    @test LW.trade_request_processing(f.maps[b],LW.RDLBody.Body(10.,0.,100.,1.),nothing,f.kitchen(b),5,7;items=f.items)===nothing
    no_payment=copy(f.event);no_payment["offered"]=Dict{Int,Int}()
    @test LW.configured_camp_trade_interest(no_payment,f.states[b],f.maps[b],f.w.bodies[b],nothing,f.foods.personal[b],1;kitchen=f.kitchen(b),processing_requests=true)===nothing
    raw=processing_fixture(caller_cooks=true,supplier_cooks=false);a,b,c=raw.ids
    processing_tick(raw,1_000_000)
    visible=LW.configured_camp_trade_view(raw.states[a],LW.item_visible(raw.items,raw.w,(0.,0.),a,0.,2_000_000;foods=raw.foods),2_000_000)
    @test LW.configured_camp_trade_plan!(raw.states[a],visible,raw.w.bodies[a],nothing,raw.foods.personal[a],2_000_000;
        map=raw.maps[a],kitchen=merge(raw.kitchen(a),(processing=false,)))===nothing
    both=processing_fixture(caller_cooks=true,supplier_cooks=true);a,b,c=both.ids
    processing_tick(both,1_000_000)
    @test both.states[a]["camp_trade"]["meeting"]["supply"]["mode"]=="recipient_processing"
    @test Set(keys(both.event["processing_inputs"][5]))==Set(["input","output"])
end
@testset "raw-only supply reaches ordinary negotiation" begin
    for caller_cooks in (false,true)
        exchanged=0
        for seed in 1:32
            f=processing_fixture(seed;caller_cooks,supplier_cooks=!caller_cooks);a,b,c=f.ids
            processing_tick(f,1_000_000)
            @test f.states[b]["camp_trade"]["replied"]==1
            now=2_000_000
            if caller_cooks
                @test f.states[a]["camp_trade"]["meeting"]["kind"]==5
                @test f.states[a]["camp_trade"]["meeting"]["goal_kind"]==7
                @test f.foods.processed[5]==0
            else
                now,ticks=prepare_supplier!(f,b,now)
                @test ticks==122
                @test f.foods.processed[5]==1
                processing_tick(f,now)
                @test f.states[a]["camp_trade"]["meeting"]["announced"]==Dict(7=>1)
            end
            if negotiate_processing!(f,now+1_000_000)
                exchanged+=1
                @test f.foods.personal[a][caller_cooks ? 5 : 7]>0
                if caller_cooks
                    f.states[a]["camp_trade"]["meeting"]["preparation"]=LW.trade_request_processing(f.maps[a],f.w.bodies[a],nothing,f.kitchen(a),5,7)
                    _,ticks=prepare_supplier!(f,a,now+3_000_000)
                    @test ticks==122 && f.foods.personal[a][7]>0
                end
            end
        end
        @test exchanged>0
        println(JSON3.write((mode=caller_cooks ? "recipient_processing" : "supplier_processing",exchanged,total=32)))
    end
end
