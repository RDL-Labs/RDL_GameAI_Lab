# 暫定固定：相手が加工・調理中なら、取引を提示せずその場で待つ。
# 目的：作業中に応答できず、30秒の提案期限が尽きることを避ける。
# 設定：scene.configured_trade_work_wait（既定false、釣り実験ではtrue）。
# 将来：声かけ → 作業中という応答 → 待機・中断・離脱のMB選択へ置換する。
# 現在は直前tickの実行結果を直接参照するショートカット（視覚認識ではない）。
# 全個体が同じtick開始時のスナップショットを見る。開始直後は1tick遅れ得る。
# 待機は成功・失敗の学習ではない。終了後は在庫・要求から取引を再評価する。
# 安全・食事など既存の上位行動は優先。夜・離別・翌日は待機を取り消す。
# 記録：incidental_items.configured_work_wait と events.configured_rule。
function configured_trade_workers(previous)
    Set(a for (a,sig) in previous if length(sig)>=5 && sig[3]=="process_food" && sig[5]=="processing")
end

# 暫定固定：提示済みなら返答・期限切れまでその場で待つ。
# configured_trade_work_wait と共に有効化。上位の安全・食事処理は優先。
# 将来は交渉継続の見積もりから待つ／立ち去ることを選ぶMBへ置換する。
function configured_trade_reply_wait(state,items,w,home,a,now)
    for offer in values(items["offers"])
        offer["proposer"]==a && now<offer["expires_us"] || continue
        item_trade_contact(w,home,a,offer["target"]) || continue
        q=configured_trade_wait_state(state)
        q["reply_ticks"]=get(q,"reply_ticks",0)+1
        return D("action"=>"rest","method"=>"configured_trade_reply_wait",
            "configured_rule"=>"wait_for_trade_reply","selection_mode"=>"configured","target"=>offer["target"])
    end
    nothing
end

# 暫定固定：同時tickの相手の移動計画を直接見て、提示を実行前に見送る。
# 将来は声かけへの応答で交渉開始を合意する。現状の実行順による失敗を防ぐ。
# 提示未実行なので開始回数・期限を消費せず、交換失敗として学習させない。
function configured_trade_departure_guard!(plans,states,workers,now,day_us;relations=nothing)
    departing=Set(a for (a,p) in plans if get(p,"action",nothing) in ("walk","run","climb"))
    for (a,p) in plans
        get(p,"action",nothing)=="item_offer" || continue
        p["target"] in departing || continue
        replacement=configured_trade_wait_intercept!(states[a],p,departing,now,day_us;
            relation=relations===nothing ? nothing : relations[a])
        replacement["purpose_family"]=p["purpose_family"]
        # Post-selection replacement must retain the parent's frozen bookkeeping,
        # but must not carry offer-specific trial/credit traces into a rest action.
        for key in ("trail_parent","bundle_parent")
            haskey(p,key) && (replacement[key]=p[key])
        end
        replacement["configured_rule"]="defer_trade_departing_partner"
        q=configured_trade_wait_state(states[a]);q["departure_deferrals"]=get(q,"departure_deferrals",0)+1
        plans[a]=replacement
    end
end
function configured_trade_wait_state(state)
    get!(state,"configured_work_wait") do
        D("target"=>nothing,"day"=>-1,"entries"=>0,"ticks"=>0,"released"=>0,"cancelled"=>0)
    end
end
function configured_trade_wait_rest!(q)
    q["ticks"]+=1
    D("action"=>"rest","method"=>"configured_trade_work_wait","configured_rule"=>"wait_before_trade_offer",
      "selection_mode"=>"configured","target"=>q["target"])
end
function configured_trade_wait_poll!(state,workers,partners,now,day_us;eligible=true,incoming=false)
    q=configured_trade_wait_state(state);target=q["target"]
    target===nothing && return nothing
    if !eligible || q["day"]!=div(now,day_us) || !(target in partners) || incoming
        q["target"]=nothing;q["cancelled"]+=1
        return nothing
    end
    target in workers && return configured_trade_wait_rest!(q)
    q["target"]=nothing;q["released"]+=1
    state["social"]["next_us"]=0 # permit fresh valuation; never replay saved terms
    nothing
end
function configured_trade_wait_intercept!(state,plan,workers,now,day_us;relation=nothing)
    plan===nothing && return nothing
    get(plan,"action",nothing)=="item_offer" || return plan
    plan["target"] in workers || return plan
    mind=state["social"]
    resolve_method!(mind["offer"],plan["source"],nothing,nothing;creditable=false,goal_H_increment=0.)
    gradient_result!(relation,plan["source"],"configured_wait";now)
    q=configured_trade_wait_state(state)
    q["target"]=plan["target"];q["day"]=div(now,day_us);q["entries"]+=1
    configured_trade_wait_rest!(q)
end
