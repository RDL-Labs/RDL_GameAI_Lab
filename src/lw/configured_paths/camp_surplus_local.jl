# 暫定固定: scene.camp_trade_surplus=false。通常LWでは明示ON時のみ接続。
# 自己の期限予測から売却候補を作り、実験が候補を採用して呼びかける。
# 一斉通知/先着買い手は会話アダプタ。将来は注意・参加費用・MB選択へ。
# 全在庫は公開せず、提示は1個。既存CAMP_TRADE_CALL_RULESの数量/期限を共用。
function configured_surplus_candidates(map,body,gut,stock;relation=nothing)
    security=get(map,"food_security",food_security(relation))
    security===nothing && return Any[]
    get(security,"expiry",nothing)===nothing && return Any[]
    valuation=trade_valuation_context(body,gut,security,D(),nothing)
    rows=Any[]
    for kind in trade_request_recall(map)
        stock[kind]>=CAMP_TRADE_CALL_RULES.offered_quantity || continue
        RDLBody.food_edible(kind) || continue
        after=copy(stock);after[kind]-=CAMP_TRADE_CALL_RULES.offered_quantity
        weight=food_trade_weight(body,gut,kind;map)
        material=weight*(log1p(after[kind])-log1p(stock[kind]))
        gradient=trade_compound_gradient(stock,after,material,valuation)
        # A possible payment is deliberately not invented here.
        gradient["waste_relief"]>0 && gradient["total"]>0 || continue
        push!(rows,D("kind"=>kind,"quantity"=>CAMP_TRADE_CALL_RULES.offered_quantity,"gradient"=>gradient))
    end
    rows
end
function configured_surplus_reply!(seller,buyer,row,states,maps,world,foods,now;gut=nothing,announced=false)
    # Local delivery assumes both awake, available and in audible camp range.
    # It consults each owner's own state only; buyer sees the announced row.
    seller==buyer && return nothing
    seller_channel=configured_camp_trade_state!(states[seller])
    (seller_channel["meeting"]!==nothing || (!announced && seller_channel["outgoing"]!==nothing)) && return nothing
    configured_camp_trade_state!(states[buyer])["meeting"]!==nothing && return nothing
    kind=row["kind"]
    foods.personal[seller][kind]>=row["quantity"] || return nothing
    kind in trade_request_recall(maps[buyer]) || return nothing
    body=world.bodies[buyer];stock=foods.personal[buyer]
    weight=food_trade_weight(body,gut,kind;map=maps[buyer])
    weight>0 || return nothing
    after=copy(stock);after[kind]+=row["quantity"]
    valuation=trade_valuation_context(body,gut,get(maps[buyer],"food_security",nothing),D(),nothing)
    gradient=trade_compound_gradient(stock,after,weight*(log1p(after[kind])-log1p(stock[kind])),valuation)
    gradient["total"]>0 || return nothing
    configured_camp_trade_state!(states[buyer])["outgoing"]=nothing
    # Buyer proposes terms through the existing private-stock negotiation.
    expiry=now+CAMP_TRADE_CALL_RULES.lifetime_us
    configured_camp_trade_state!(states[buyer])["meeting"]=D("peer"=>seller,"initiator"=>true,"kind"=>kind,
        "announced"=>Dict(kind=>row["quantity"]),"expires_us"=>expiry,"evaluated"=>false)
    configured_camp_trade_state!(states[seller])["meeting"]=D("peer"=>buyer,"initiator"=>false,"kind"=>nothing,
        "announced"=>Dict{Int,Int}(),"expires_us"=>expiry,"evaluated"=>false)
    !announced && configured_camp_trade_record!(states[seller],"sell_call",now;kind,quantity=row["quantity"],gradient=row["gradient"])
    configured_camp_trade_record!(states[buyer],"sell_reply",now;peer=seller,kind,gradient)
    gradient
end
