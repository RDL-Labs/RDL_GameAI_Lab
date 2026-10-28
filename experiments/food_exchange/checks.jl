# Resource tests exercise the authoritative transaction API, not the selection policy.
include("../personal_food/checks.jl")
if !isdefined(LW,:food_exchange_state)
    Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/world/food_exchange.jl")))
end
const TRADE_HOME=(0.,0.)
function exchange_fixture(;receiver=[B.RAW_ACORN,B.RAW_ACORN,B.RAW_ACORN,B.RAW_ACORN])
    f=fixture(kinds=[[B.FRUIT_FOOD,B.FRUIT_FOOD,B.FRUIT_FOOD],receiver,[B.ACORN_MEAL]])
    for a in LW.IDS;store_personally!(f,a);end
    (f=f,s=LW.food_exchange_state())
end
function make_offer!(x;now=0,op="offer",actor=A,target=OTHER,give_kind=B.FRUIT_FOOD,give_count=1,want_kind=B.RAW_ACORN,want_count=2)
    LW.food_exchange_execute!(x.s,x.f.r,x.f.w,x.f.stores,TRADE_HOME,actor,op,"trade_offer",now;
        target,give_kind,give_count,want_kind,want_count)
end
function answer_offer!(x,id;actor=OTHER,op="accept",action="trade_accept",now=1_000_000)
    LW.food_exchange_execute!(x.s,x.f.r,x.f.w,x.f.stores,TRADE_HOME,actor,op,action,now;offer_id=id)
end
trade_view(x,a,now=0)=LW.food_exchange_view(x.s,x.f.r,x.f.w,TRADE_HOME,a,now)

@testset "exchange proposal is private and does not reserve or transfer stock" begin
    x=exchange_fixture();before=LW.food_snapshot(x.f.r)
    offer=make_offer!(x);id=offer["offer_id"]
    @test offer["status"]=="offered" && LW.food_snapshot(x.f.r)==before
    @test length(x.s["offers"])==1 && audit(x.f)===nothing
    own=trade_view(x,A);other=trade_view(x,OTHER)
    @test own["outgoing"]==id && isempty(own["incoming"])
    @test other["incoming"][1]["id"]==id && other["own_stock"]==[0,0,4,0]
    @test all(p->p isa String,other["partners"]) && !haskey(other,"personal")
    # Another owner's undisclosed stock cannot change the proposer's observation.
    hidden=saved_copy(x);hidden.f.r.personal[OTHER][3]+=1;hidden.f.stores[OTHER]+=1;hidden.f.r.initial[3]+=1
    @test trade_view(hidden,A)==own && audit(hidden.f)===nothing
    other["own_stock"][3]=999;other["incoming"][1]["give_count"]=999
    push!(other["notices"],Dict("status"=>"invented"))
    @test x.f.r.personal[OTHER][3]==4 && x.s["offers"][id]["give_count"]==1 && isempty(x.s["notices"][OTHER])
    snap=LW.food_exchange_snapshot(x.s);snap["active"][1]["want_count"]=999
    @test x.s["offers"][id]["want_count"]==2
    replay=make_offer!(x)
    @test replay==offer && x.s["counts"]["offered"]==1
    replay["status"]="invented"
    @test make_offer!(x)["status"]=="offered"
    occupied=make_offer!(x;now=1_000_000,op="second-offer")
    @test occupied["reason"]=="outgoing_pending" && LW.food_snapshot(x.f.r)==before
    empty_peer=exchange_fixture(receiver=Int[])
    @test make_offer!(empty_peer)["status"]=="offered" # no omniscient partner stock gate
end

@testset "accepted barter is atomic and replay safe" begin
    x=exchange_fixture();id=make_offer!(x)["offer_id"]
    hand=deepcopy(x.f.w.inventory);cargo=deepcopy(x.f.cargo);outside=copy(x.f.r.personal[C])
    accepted=answer_offer!(x,id)
    @test accepted["status"]=="exchanged" && isempty(x.s["offers"])
    @test x.f.r.personal[A]==[2,0,2,0] && x.f.r.personal[OTHER]==[1,0,2,0]
    @test x.f.stores[A]==4 && x.f.stores[OTHER]==3
    @test x.f.w.inventory==hand && x.f.cargo==cargo && x.f.r.personal[C]==outside
    @test x.f.r.shared==zeros(Int,4) && audit(x.f)===nothing
    @test all(last(x.s["notices"][a])["status"]=="exchanged" for a in (A,OTHER))
    before=LW.food_snapshot(x.f.r);state=LW.food_exchange_snapshot(x.s)
    @test answer_offer!(x,id)==accepted
    @test LW.food_snapshot(x.f.r)==before && LW.food_exchange_snapshot(x.s)==state
    @test_throws ErrorException answer_offer!(x,id;op="conflicting-op")
    @test_throws ErrorException answer_offer!(x,id;action="trade_decline")
    @test_throws ErrorException answer_offer!(x,id;now=0,op="older-op")
    @test LW.food_snapshot(x.f.r)==before
    later=answer_offer!(x,id;now=2_000_000,op="already-complete")
    @test later["status"]=="unavailable" && LW.food_snapshot(x.f.r)==before
    @test x.s["counts"]["exchanged"]==1
end

@testset "only the recipient can consent or decline" begin
    x=exchange_fixture();id=make_offer!(x)["offer_id"];before=LW.food_snapshot(x.f.r)
    for (n,action) in enumerate(("trade_accept","trade_decline"))
        outsider=answer_offer!(x,id;actor=C,action,now=n*1_000_000,op="outsider:$n")
        @test outsider["reason"]=="not_recipient" && haskey(x.s["offers"],id)
        @test LW.food_snapshot(x.f.r)==before
    end
    declined=answer_offer!(x,id;action="trade_decline",now=3_000_000,op="decline")
    @test declined["status"]=="declined" && isempty(x.s["offers"])
    @test LW.food_snapshot(x.f.r)==before && audit(x.f)===nothing
end

@testset "exchange outcomes reveal only immutable personal stock changes" begin
    x=exchange_fixture();id=make_offer!(x)["offer_id"]
    before=Dict(a=>copy(x.f.r.personal[a]) for a in (A,OTHER))
    # Change an undisclosed warehouse in independent worlds before acceptance.
    # Public terms and the other party's observations must remain identical.
    more_receiver=saved_copy(x);more_proposer=saved_copy(x)
    for (alternate,owner,kind) in ((more_receiver,OTHER,B.RAW_ACORN),(more_proposer,A,B.FRUIT_FOOD))
        alternate.f.r.personal[owner][kind]+=2
        alternate.f.stores[owner]+=2;alternate.f.r.initial[kind]+=2
    end
    accepted=answer_offer!(x,id);expected_receipt=deepcopy(accepted)
    receiver_receipt=answer_offer!(more_receiver,id)
    proposer_receipt=answer_offer!(more_proposer,id)
    views=Dict(a=>trade_view(x,a,1_000_000) for a in (A,OTHER))
    notices=Dict(a=>deepcopy(only(views[a]["notices"])) for a in (A,OTHER))
    @test before[A]==[3,0,0,0] && before[OTHER]==[0,0,4,0]
    for a in (A,OTHER)
        @test notices[a]["own_before"]==before[a]
        @test notices[a]["own_after"]==x.f.r.personal[a]
    end
    @test accepted["own_before"]==before[OTHER] && accepted["own_after"]==[1,0,2,0]
    @test receiver_receipt["own_before"]==[0,0,6,0] && receiver_receipt["own_after"]==[1,0,4,0]
    @test trade_view(more_receiver,A,1_000_000)==views[A]
    @test proposer_receipt==accepted && trade_view(more_proposer,OTHER,1_000_000)==views[OTHER]
    public_keys=Set(("id","proposer","target","give_kind","give_count","want_kind","want_count",
                     "created_us","expires_us","offer_id","status","us"))
    for a in (A,OTHER)
        @test Set(keys(notices[a]))==union(public_keys,Set(("own_before","own_after")))
    end
    @test Set(keys(accepted))==Set(("actor","operation","action","us","status","offer_id","reason","own_before","own_after"))
    @test isempty(trade_view(x,C,1_000_000)["notices"])
    @test Set(keys(last(LW.food_exchange_snapshot(x.s)["records"])))==public_keys
    @test all(audit(y.f)===nothing for y in (x,more_receiver,more_proposer))

    # Neither the returned receipt nor either party's display owns live arrays.
    resources=LW.food_snapshot(x.f.r)
    accepted["own_before"][3]=999;accepted["own_after"][1]=999
    for a in (A,OTHER)
        views[a]["notices"][1]["own_before"][1]=888
        views[a]["notices"][1]["own_after"][3]=888
    end
    @test LW.food_snapshot(x.f.r)==resources
    @test all(only(trade_view(x,a,1_000_000)["notices"])==notices[a] for a in (A,OTHER))
    replay=answer_offer!(x,id)
    @test replay==expected_receipt
    replay["own_after"][1]=777
    @test answer_offer!(x,id)==expected_receipt && x.s["counts"]["exchanged"]==1

    # Subsequent legitimate withdrawals also cannot rewrite transaction history.
    for a in (A,OTHER);take_personally!(x.f,a);end
    @test all(x.f.r.personal[a]!=notices[a]["own_after"] for a in (A,OTHER))
    @test all(only(trade_view(x,a,1_000_000)["notices"])==notices[a] for a in (A,OTHER))
    @test answer_offer!(x,id)==expected_receipt && audit(x.f)===nothing
    restored=saved_copy(x)
    @test answer_offer!(restored,id)==expected_receipt
    @test all(trade_view(restored,a,1_000_000)==trade_view(x,a,1_000_000) for a in (A,OTHER))
    @test LW.food_snapshot(restored.f.r)==LW.food_snapshot(x.f.r) && audit(restored.f)===nothing
end

@testset "expired or unreachable proposals cannot move either side" begin
    x=exchange_fixture();id=make_offer!(x)["offer_id"];before=LW.food_snapshot(x.f.r)
    @test isempty(trade_view(x,OTHER,LW.FOOD_EXCHANGE_TTL_US)["incoming"])
    expired=answer_offer!(x,id;now=LW.FOOD_EXCHANGE_TTL_US)
    @test expired["status"]=="unavailable" && x.s["counts"]["expired"]==1
    @test all(last(x.s["notices"][a])["status"]=="expired" for a in (A,OTHER))
    @test LW.food_snapshot(x.f.r)==before && audit(x.f)===nothing
    LW.food_exchange_expire!(x.s,LW.FOOD_EXCHANGE_TTL_US+1)
    @test x.s["counts"]["expired"]==1
    for action in ("trade_accept","trade_decline")
        away=exchange_fixture();oid=make_offer!(away)["offer_id"]
        away.f.w.positions[OTHER]=(2.,0.);before=LW.food_snapshot(away.f.r)
        result=answer_offer!(away,oid;action)
        @test result["status"]=="unavailable" && result["reason"]=="partner_unavailable"
        @test LW.food_snapshot(away.f.r)==before && audit(away.f)===nothing
    end
    separated=exchange_fixture();separated.f.w.positions[A]=(-1.2,0.);separated.f.w.positions[OTHER]=(1.2,0.)
    @test make_offer!(separated)["status"]=="unavailable" # both at home, outside contact range
    deaf=exchange_fixture();deaf.f.w.hearing[OTHER]=false
    @test make_offer!(deaf)["status"]=="unavailable" && isempty(deaf.s["offers"])
end

@testset "stocks are revalidated at acceptance with no partial payment" begin
    for emptied in (A,OTHER)
        x=exchange_fixture();id=make_offer!(x)["offer_id"]
        # Warehouse contents remain available for eating/preparation while waiting.
        for _ in 1:3;take_personally!(x.f,emptied);end
        before=LW.food_snapshot(x.f.r);totals=copy(x.f.stores);hand=copy(x.f.w.inventory);cargo=deepcopy(x.f.cargo)
        result=answer_offer!(x,id)
        @test result["status"]=="unavailable" && result["reason"]=="stock_unavailable"
        @test LW.food_snapshot(x.f.r)==before && x.f.stores==totals
        @test x.f.w.inventory==hand && x.f.cargo==cargo && audit(x.f)===nothing
        @test isempty(x.s["offers"]) && x.s["counts"]["exchanged"]==0
    end
    wrong_total=exchange_fixture();id=make_offer!(wrong_total)["offer_id"]
    wrong_total.f.stores[OTHER]+=1;before=LW.food_snapshot(wrong_total.f.r)
    @test_throws ErrorException answer_offer!(wrong_total,id)
    @test LW.food_snapshot(wrong_total.f.r)==before
    wrong_total.f.stores[OTHER]-=1
    @test audit(wrong_total.f)===nothing
end

@testset "pending exchange survives a checkpoint" begin
    x=exchange_fixture();id=make_offer!(x)["offer_id"];restored=saved_copy(x)
    @test trade_view(restored,OTHER)==trade_view(x,OTHER)
    @test answer_offer!(restored,id)==answer_offer!(x,id)
    @test LW.food_snapshot(restored.f.r)==LW.food_snapshot(x.f.r)
    @test restored.f.stores==x.f.stores && LW.food_exchange_snapshot(restored.s)==LW.food_exchange_snapshot(x.s)
    @test audit(restored.f)===nothing && audit(x.f)===nothing
end

@testset "invalid terms fail before mutation and history stays bounded" begin
    for terms in ((give_kind=true,),(give_count=true,),(give_count=0,),(want_count=5,),
                  (want_count=1.5,),(want_kind=B.FRUIT_FOOD,),(want_kind=5,))
        x=exchange_fixture();before=LW.food_snapshot(x.f.r)
        @test_throws ErrorException make_offer!(x;terms...)
        @test LW.food_snapshot(x.f.r)==before && isempty(x.s["offers"])
    end
    x=exchange_fixture();before=LW.food_snapshot(x.f.r)
    for n in 0:35
        now=2_000_000n;id=make_offer!(x;now,op="offer:$n")["offer_id"]
        answer_offer!(x,id;action="trade_decline",now=now+1_000_000,op="decline:$n")
    end
    @test x.s["counts"]["offered"]==36 && x.s["counts"]["declined"]==36
    @test length(x.s["records"])<=64 && all(length(v)<=32 for v in values(x.s["notices"]))
    @test length(x.s["receipts"])<=length(LW.IDS) && isempty(x.s["offers"])
    @test_throws ErrorException make_offer!(x;now=0,op="offer:0")
    @test LW.food_snapshot(x.f.r)==before && audit(x.f)===nothing
end

@testset "proposal replays still enforce integer resource terms" begin
    x=exchange_fixture();offer=make_offer!(x)
    resources=LW.food_snapshot(x.f.r);state=deepcopy(x.s);totals=copy(x.f.stores)
    @test offer["status"]=="offered"
    for terms in ((give_count=true,),(give_count=1.0,),(give_kind=true,),(give_kind=1.0,))
        # These compare numerically equal to the valid proposal's fields.
        # Matching operation identity must not bypass their type checks.
        @test_throws ErrorException make_offer!(x;terms...)
        @test x.s==state && LW.food_snapshot(x.f.r)==resources && x.f.stores==totals
        @test make_offer!(x)==offer && x.s==state
    end
    @test audit(x.f)===nothing
end
