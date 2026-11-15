# 暫定固定・世界側供給。personal_food_supply未指定ならOFF。
# 個人倉庫へ日初に設定個数を追加し、品質・期限・総数・種類別収支を同時更新。
# 個体の行動や交換成立を強制しない。将来は生産/配送など世界過程へ置換。
# replenishmentsに所有者/種類/数量/期限を保存し、再適用を防ぐ。
function configured_personal_food_supply!(foods,stores,ledger,supply,day,now;shared_stores=false)
    supply===nothing && return 0
    foods!==nothing && !shared_stores || error("personal supply requires typed personal stores")
    rows=Tuple{String,Int,Int}[]
    for (owner,row) in pairs(supply)
        actor=String(owner);haskey(stores,actor) || error("unknown supply owner")
        kind=Int(checked_food_kind(row["kind"]));quantity=row["quantity"]
        quantity isa Integer && !(quantity isa Bool) && quantity>=0 || error("invalid supply quantity")
        push!(rows,(actor,kind,Int(quantity)))
    end
    total=0
    for (actor,kind,quantity) in sort!(rows)
        any(r->get(r,"source",nothing)=="personal_food_supply" && r["day"]==day && r["actor"]==actor,ledger) && continue
        deadline=food_deadline(foods,kind)
        food_quality_store_add!(foods,actor,kind,2,quantity;deadline)
        foods.personal[actor][kind]+=quantity;stores[actor]+=quantity;foods.added[kind]+=quantity
        push!(ledger,D("source"=>"personal_food_supply","day"=>day,"us"=>now,
            "actor"=>actor,"kind"=>kind,"added"=>quantity,"deadline"=>deadline))
        total+=quantity
    end
    total
end
