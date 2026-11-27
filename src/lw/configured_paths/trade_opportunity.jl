# 暫定固定・局所実験: incidental.trade_opportunity の明示有効化のみ (既定OFF)。
# 日次上限を外し、本人の取引勾配と結果残差で再試行を評価する。
# 初期成功見込みと呼びかけ費用は暫定。将来は実際の所要時間・経験から見積もる。
# 他者の非公開在庫は読まない。無返答は在庫不存在の証明ではない。
const TRADE_OPPORTUNITY_RULES=(initial_probability=.5,effort=.25)
configured_trade_opportunity_enabled(state)=haskey(state,"trade_opportunity")
function configured_trade_opportunity_enable!(state)
    get!(() -> D("evidence"=>D(),"pending"=>nothing,"ready_home"=>false),state,"trade_opportunity")
end
function configured_trade_opportunity_score(state,key,benefit)
    evidence=get(state["trade_opportunity"]["evidence"],key,nothing)
    probability=evidence===nothing ? TRADE_OPPORTUNITY_RULES.initial_probability :
        (evidence["successes"]+TRADE_OPPORTUNITY_RULES.initial_probability)/(evidence["trials"]+1)
    residual=evidence===nothing ? 0. : evidence["H"]
    expected=max(0.,benefit)*probability
    (priority=expected-residual-TRADE_OPPORTUNITY_RULES.effort,expected=expected,probability=probability,H=residual)
end
function configured_trade_opportunity_begin!(state,key,benefit,event)
    forecast=configured_trade_opportunity_score(state,key,benefit)
    state["trade_opportunity"]["pending"]=D("key"=>key,"expected"=>forecast.expected,"benefit"=>benefit,"event"=>event["id"])
    state["trade_opportunity"]["ready_home"]=false
end
function configured_trade_opportunity_finish!(state,success,now;reason)
    configured_trade_opportunity_enabled(state) || return
    opportunity=state["trade_opportunity"];trial=opportunity["pending"]
    trial===nothing && return
    evidence=get!(() -> D("trials"=>0,"successes"=>0,"H"=>0.),opportunity["evidence"],trial["key"])
    evidence["trials"]+=1;evidence["successes"]+=success
    # 成立時はこの試行の見込みだけを実現した近似。身体・他目的のHを消さない。
    evidence["H"]=success ? 0. : evidence["H"]+trial["expected"]
    opportunity["pending"]=nothing
    configured_camp_trade_record!(state,"opportunity_result",now;key=trial["key"],success,reason,H=evidence["H"],expected=trial["expected"])
end
function configured_trade_opportunity_cancel!(state,now)
    configured_trade_opportunity_enabled(state) || return
    trial=state["trade_opportunity"]["pending"]
    trial===nothing && return
    state["trade_opportunity"]["pending"]=nothing
    configured_camp_trade_record!(state,"opportunity_interrupted",now;key=trial["key"],reason="responding_to_other_call")
end
# 他の用事・身体要求は呼出側が blocked/demand として渡す。帰宅先・移動は既存処理。
function configured_trade_opportunity_house!(state,house_state,house,position,yaw,now,day_us,rows;blocked=false,demand=0.)
    configured_house_plan!(house_state,house,position,yaw,now,day_us,rows;
        eligible=get(state["trade_opportunity"],"ready_home",false),
        blocked=blocked || configured_camp_trade_busy(state),demand)
end
