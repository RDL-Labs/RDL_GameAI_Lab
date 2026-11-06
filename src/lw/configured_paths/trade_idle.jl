# Computational suspension after a return meal and a trade decision, not cognition.
function configured_trade_idle_ready!(map,state,items,w,a,now,day_us;social_notice=false)
    gate=get!(map,"configured_trade_idle",D("day"=>-1,"ready"=>false,"wakeups"=>0))
    if gate["day"]!=div(now,day_us)
        gate["day"]=div(now,day_us);gate["ready"]=false
    end
    incoming=any(o->o["target"]==a && now<o["expires_us"] && item_contact(w,a,o["proposer"]),values(items["offers"]))
    mind=get(state,"social",nothing)
    busy=mind!==nothing && mind["pending"]!==nothing
    if incoming || busy || social_notice
        gate["ready"] && (gate["wakeups"]+=1)
        gate["ready"]=false
    end
    gate["ready"]
end
# 暫定固定：援助要求・応答の通知でも帰還後停止を解除する。
# configured_trade_idle と social_relationships の併用時のみ使用。
# 観測と同じ3秒の通知寿命。将来は注意・呼びかけ認識による起動へ置換する。
configured_social_notice(w,a,answered)=any(m->0<=w.seconds-m["time"]<3 &&
    !(m["id"] in answered),w.inbox[a])
function configured_trade_idle_considered!(map,state,view,plan,now,day_us;allow_start=true)
    view===nothing && return
    gate=get!(map,"configured_trade_idle",D("day"=>div(now,day_us),"ready"=>false,"wakeups"=>0))
    mind=get(state,"social",nothing)
    busy=mind!==nothing && mind["pending"]!==nothing
    # A skipped cooldown is not a decision. A completed evaluation writes next_us.
    considered=mind!==nothing && mind["next_us"]==now+64_000_000
    idle=plan===nothing && !busy && isempty(view["incoming"]) && view["outgoing"]===nothing &&
        (considered || !allow_start)
    gate["ready"]=idle;gate["day"]=div(now,day_us)
    idle && (gate["last_decision_us"]=now)
end
