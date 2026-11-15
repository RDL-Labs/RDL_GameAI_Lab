# 暫定固定: configured_identity_calls=false(既定)。不明な外見の候補名を呼び、
# 自分の名前が聞こえたら音の方へscanする。名前既知を教示ショートカットとする。
# 呼びかけ選択は未学習。身体更新は通常scan経由、取引・援助の旧通知は変更しない。
# 将来は共通MBの確認行動選択へ置換。identity_observation.callsに記録。
const IDENTITY_CALL_RULES=(range=8.,bearing_step=15.,interval_us=64_000_000,
    lifetime_us=64_000_000,records=32)
function configured_identity_calls_state!(relation)
    get!(() -> D("emitted"=>0,"heard"=>0,"turned"=>0,"expired"=>0,
        "pending"=>nothing,"used_names"=>String[],"day"=>-1,"next_us"=>0,"records"=>Any[]),
        relation["identity_observation"],"calls")
end
function configured_identity_call_notice!(relation,now)
    relation===nothing && return nothing
    identity=get(relation,"identity_observation",nothing);identity===nothing && return nothing
    state=get(identity,"calls",nothing);state===nothing && return nothing
    cue=state["pending"];cue===nothing && return nothing
    if now>=cue["expires_us"]
        state["expired"]+=1;state["pending"]=nothing;return nothing
    end
    now>cue["us"] ? "identity_name_call" : nothing
end
function configured_identity_call_plan!(relation,yaw,now,day_us)
    identity=get(relation,"identity_observation",nothing);identity===nothing && return nothing
    state=configured_identity_calls_state!(relation)
    if configured_identity_call_notice!(relation,now)!==nothing
        cue=state["pending"]
        return D("action"=>"scan","method"=>"identity_answer_turn","configured_rule"=>"identity_answer_turn",
            "scan_angle"=>mod(cue["bearing"]-yaw+180,360)-180,"identity_answer"=>true,"configured_observation"=>true)
    end
    day=div(now,day_us)
    if state["day"]!=day
        empty!(state["used_names"]);state["day"]=day
    end
    now>=state["next_us"] || return nothing
    for row in identity["current"]
        row["status"] in ("ambiguous","insufficient_observation") || continue
        for peer in row["candidates"]
            name=identity["names"][peer]
            name in state["used_names"] && continue
            return D("action"=>"scan","method"=>"identity_name_call","configured_rule"=>"identity_name_call",
                "scan_angle"=>row["bearing"],"identity_call_name"=>name,"configured_observation"=>true)
        end
    end
    nothing
end
function configured_identity_call_log!(state,row)
    push!(state["records"],row)
    length(state["records"])>IDENTITY_CALL_RULES.records && popfirst!(state["records"])
end
# Auditory world adapter. Broadcast text, not a selected actor's ID. Receivers
# match their own known name; cues carry only text, quantized bearing and time.
function configured_identity_call_execute!(relations,w,actor,plan,roster,now)
    state=configured_identity_calls_state!(relations[actor])
    if get(plan,"identity_answer",false)
        cue=state["pending"];cue===nothing && return
        state["turned"]+=1
        configured_identity_call_log!(state,D("us"=>now,"event"=>"turned","cue"=>copy(cue)))
        state["pending"]=nothing
    elseif haskey(plan,"identity_call_name")
        name=plan["identity_call_name"];state["emitted"]+=1
        push!(state["used_names"],name);state["next_us"]=now+IDENTITY_CALL_RULES.interval_us
        configured_identity_call_log!(state,D("us"=>now,"event"=>"called","name"=>name))
        p=w.positions[actor]
        for other in sort!(collect(keys(w.positions)))
            other==actor && continue
            w.hearing[other] || continue
            roster[other]["name"]==name || continue
            q=w.positions[other];hypot(p[1]-q[1],p[2]-q[2])<=IDENTITY_CALL_RULES.range || continue
            get!(() -> configured_peer_identity_memory(other,roster),relations[other],"identity_observation")
            receiver=configured_identity_calls_state!(relations[other])
            receiver["pending"]!==nothing && continue
            cue=D("text"=>name*"！","bearing"=>IDENTITY_CALL_RULES.bearing_step*round(atand(p[1]-q[1],p[2]-q[2])/IDENTITY_CALL_RULES.bearing_step),
                "us"=>now,"expires_us"=>now+IDENTITY_CALL_RULES.lifetime_us)
            receiver["pending"]=cue;receiver["heard"]+=1
        end
    end
end
