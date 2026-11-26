# 暫定固定: scene.camp_trade_processing=false (default). Known recipe,
# retrieve -> work -> deposit sequence, below safety and own hunger priorities,
# implements a reply's tentative supply plan, not general-purpose planning.
# Physical executors still check possession, facilities, effort and completion.
# Future: a learned child preparation MB. Trace: camp_trade records/preparation.
function configured_camp_processing_plan(state,map,body,gut,kitchen,now;items=nothing,at_home=false)
    kitchen===nothing && return nothing
    meeting=configured_camp_trade_state!(state)["meeting"]
    meeting===nothing && return nothing
    now<meeting["expires_us"] || return nothing
    preparation=get(meeting,"preparation",nothing)
    preparation===nothing && return nothing
    foods=kitchen.foods;actor=state["actor"]
    input=preparation["input"];output=preparation["output"]
    foods.personal[actor][output]>0 && return nothing
    action=if output in foods.inventory[actor]
        at_home ? "deposit" : nothing
    else
        current=trade_request_processing(map,body,gut,kitchen,input,output;items)
        if current===nothing
            return nothing
        elseif input in foods.inventory[actor]
            step(body,"process_food",length(foods.inventory[actor]))[2]=="worked" ? "process_food" : nothing
        elseif at_home && foods.personal[actor][input]>0
            "retrieve"
        else
            nothing
        end
    end
    action===nothing && return nothing
    D("action"=>action,"food_kind"=>input,"salt_id"=>preparation["salt_id"],
      "method"=>"camp_trade_prepare","configured_rule"=>"camp_trade_processing",
      "configured_observation"=>true)
end
function configured_camp_processing_ready!(states,foods,now)
    for actor in sort!(collect(keys(states)))
        meeting=configured_camp_trade_state!(states[actor])["meeting"]
        meeting===nothing && continue
        preparation=get(meeting,"preparation",nothing)
        preparation===nothing && continue
        output=preparation["output"]
        foods.personal[actor][output]>0 || continue
        peer=meeting["peer"];receiver=configured_camp_trade_state!(states[peer])["meeting"]
        receiver===nothing && continue
        receiver["peer"]==actor || continue
        receiver["announced"]=Dict(output=>1)
        delete!(meeting,"preparation")
        configured_camp_trade_record!(states[actor],"prepared_supply_ready",now;peer,input=preparation["input"],output)
    end
end
