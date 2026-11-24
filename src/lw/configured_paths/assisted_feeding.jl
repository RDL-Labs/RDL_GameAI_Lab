# 暫定固定の身体介助：選択済みのgiveだけを対象に、行動不能の生存者へ
# 渡した食品を食べさせる。援助の選択・強制・遠隔救助は行わない。
# CONFIGURED_ASSISTED_FEEDING.enabled既定true。将来は介助の実行動作へ置換。
# 受領者の身体限界は世界側の実行条件で、提供側の認知へ内部値は渡さない。
const CONFIGURED_ASSISTED_FEEDING=(enabled=true,)
function configured_assisted_feeding!(w,foods,guts,cargo,donor,receiver,op,kind,now;
        enabled=CONFIGURED_ASSISTED_FEEDING.enabled)
    receipt_key=donor*"|"*op*"|assisted_feeding"
    haskey(w.receipts,receipt_key) && return nothing
    enabled && guts!==nothing && w.bodies[receiver] isa HumanBody || return nothing
    body=w.bodies[receiver]
    body_alive(body) && body_mobility(body)<=0 && RDLBody.food_edible(kind) || return nothing
    can_ingest(guts[receiver]) && w.inventory[receiver]>0 || return nothing
    # The transfer appended exactly this item; preserve any older held items.
    item_index=length(cargo[receiver])
    item_index>0 || return nothing
    foods!==nothing && Int(foods.inventory[receiver][item_index])!=kind && error("assisted food mismatch")
    check(length(w.receipts)<w.capacity,"capacity")
    quality=foods===nothing ? 2 : food_quality(foods,receiver,item_index)
    liking=ingest!(guts[receiver],kind,body_energy(body),now;quality_bonus=game_food_bonus(kind,quality))
    w.inventory[receiver]-=1;w.consumed+=1
    deleteat!(cargo[receiver],item_index)
    if foods!==nothing
        food_remove!(foods,receiver,item_index)
        food_record_meal!(foods,receiver,kind,liking,now;quality)
    end
    record=D("donor"=>donor,"receiver"=>receiver,"food_kind"=>kind,
        "status"=>"assisted_fed","configured_rule"=>"assisted_feeding","us"=>now)
    w.receipts[receipt_key]=((receiver,kind),deepcopy(record))
    record
end
