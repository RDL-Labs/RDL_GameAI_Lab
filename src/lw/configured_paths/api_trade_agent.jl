# 暫定固定: local api_agent_run.jl only, never included by normal LW.
# E chooses among existing MB-filtered actions; scores/private peer state are hidden.
# Three actual tasting days precede trade. World pauses during API calls.
# Replace daily cap/candidate gate with autonomous attention/production later.
using Downloads
const CONFIGURED_API_AGENT=(actor="npc_e",model="gpt-4.1-2025-04-14",calls_per_day=12,
    total_calls=parse(Int,get(ENV,"RDL_API_TOTAL_CALLS","24")),output_tokens=700,history_limit=128,memory_chars=2000)
const CONFIGURED_API_SCARCE=get(ENV,"RDL_API_SCARCE","0")=="1"
# 暫定固定: three naming/tasting days; diary starts after education to reduce calls.
const CONFIGURED_API_EDUCATION_DAYS=3
configured_api_diary_due(day)=day>CONFIGURED_API_EDUCATION_DAYS
const CONFIGURED_API_SURVIVAL_LESSON="行動不能と死亡についての初期知識：この実験の人間モデルではreserveが0以下になると認知と通常行動が停止する。自分で食べる・要求する・取引する通常判断もできなくなるので、0になる前の食料確保が重要。これは行動不能であり、不可逆な死亡を確定する判定はこの人間モデルにはない。strainが1以上、またはdamageが1以上では歩行・加工などの身体動作が制限されるが、それ自体も死亡判定ではない。休むだけではreserveは補充されない。まだ消化中の食物などからreserveが正に戻れば停止条件から外れるが、他者の援助や回復を保証はできない。"
# 暫定固定: scarce local experiment only. E gets one actual tasting portion per
# education day, then no replenishment. Others retain their normal supply.
# Initial fruit=2 is set in the runner. Remove this world intervention to revert.
function configured_api_supply(supply,day;scarce=CONFIGURED_API_SCARCE)
    (!scarce || supply===nothing) && return supply
    copied=Dict(String(actor)=>Dict(String(k)=>v for (k,v) in pairs(row)) for (actor,row) in pairs(supply))
    for (actor,row) in pairs(copied)
        String(actor)==CONFIGURED_API_AGENT.actor || continue
        row["quantity"]=day<CONFIGURED_API_EDUCATION_DAYS ? 1 : 0
    end
    copied
end
# Scarcity controls replenishment only. All actors retain the normal independent
# aid request and visual aid routes; enabling them does not force an aid action.
configured_api_aid_allowed()=true
# 暫定固定: initial body education and opaque names for this local experiment.
# Names teach reference only, never taste/utility; replace with witnessed naming later.
const CONFIGURED_API_FOODS=("ネポ","ザク","リム","トセ","ワヌ","ヘキ","ソラフ","パネ")
const CONFIGURED_API_FORMS=("形カ","形ソ","形ヌ","形レ","形ホ","形ミ","形テ","形ユ")
const CONFIGURED_API_BODY_LESSON="身体の初期知識：reserveは身体のエネルギー残量、strainは疲労、damageは損傷。食べ物は消化されて時間差で身体へ供給される。食べた直後のreserveが同じでも食事が無効とはいえない。活動と時間経過でエネルギーを使う。休息は疲労を軽減するが食事の代わりではない。在庫と身体の蓄えは別で、在庫ゼロでも即座に倒れるわけではない。最初の３日は品目の呼称・外見・実食の感覚を結びつける教育期間。味の良し悪しや他者の好みは教わっておらず経験から考える。"
function configured_api_input(context)
    # Projection only: keep world IDs and other actors' semantics unchanged.
    text=JSON3.write(context)
    for (label,kind) in (("加工ドングリ",4),("生ドングリ",3),("塩焼き魚",8),("焼き魚",7),("腐敗食料",6),("生魚",5),("果実",1),("肉",2),
                         ("fruit-form",1),("acorn-form",3),("meal-form",4),("fish-form",8))
        text=replace(text,label=>(endswith(label,"-form") ? CONFIGURED_API_FORMS[kind] : CONFIGURED_API_FOODS[kind]))
    end
    text
end
const CONFIGURED_API_HISTORY=Any[]
const CONFIGURED_API_CALLS=Dict{Int,Int}()
const CONFIGURED_API_MEMORY=Ref("")
const CONFIGURED_API_EXPRESSIONS=Dict{Int,Any}()
const CONFIGURED_API_GESTURES=("none","present","release","withdraw")
# Local API interface explanation, not a command to speak or a learned motive.
const CONFIGURED_API_INPUT_LESSON="入力欄は独立しています。①choice欄：身体・取引操作をoptionsのIDから選ぶ。continueは操作を変更しない意味で、発言禁止ではない。②speech欄：自由な文字入力欄。ここに書いた文字は周囲へ声として送られる。optionsがcontinueだけでも入力でき、話すための候補や許可を別に待つ必要はない。空文字なら沈黙。何を話すか、黙るかは自分で決める。③gesture欄：none/present/release/withdrawから独立して選ぶ。声や動作が相手に届くかは観測条件により、理解・返答・受け渡しは保証されない。発言やジェスチャーだけで所有物は移動しない。reasonとmemoryは私的記録で相手には届かない。"
configured_api_input_fields()=(choice=(kind="操作候補ID",source="options"),
    speech=(kind="自由文字入力",available=true,available_with_continue=true,empty_means="沈黙"),
    gesture=(kind="独立した選択欄",choices=CONFIGURED_API_GESTURES,available_with_continue=true))
function configured_api_aid_transfer!(w,yaw,thinking,actor,target,kind,now)
    (target===nothing || kind===nothing) && return
    amounts=zeros(Int,length(CONFIGURED_API_FOODS));amounts[kind]=1
    displayed=Dict("proposer"=>actor,"target"=>target,"give_food"=>amounts,"want_food"=>zero(amounts))
    observer=CONFIGURED_API_AGENT.actor
    transfers=trade_visible_transfers(w,observer,yaw[observer],displayed,
        Dict(k=>CONFIGURED_API_FORMS[k] for k in eachindex(CONFIGURED_API_FORMS));attending=observer in thinking)
    isempty(transfers) && return
    configured_api_public!(observer,(text="",motion=nothing,appearances=String[],transfers=transfers),"object-transferred",now)
end
function configured_api_expression(event,now)
    event.actor==CONFIGURED_API_AGENT.actor || return event
    expression=pop!(CONFIGURED_API_EXPRESSIONS,Int(now),nothing)
    expression===nothing && return merge(event,(text="",motion=nothing))
    configured_api_record!((event="self_expressed",us=now,text=expression.speech,gesture=expression.gesture))
    merge(event,(text=expression.speech,motion=expression.gesture=="none" ? nothing : expression.gesture))
end
function configured_api_continue_expression!(actor,w,yaw,thinking,now)
    actor==CONFIGURED_API_AGENT.actor || return
    expression=get(CONFIGURED_API_EXPRESSIONS,Int(now),nothing)
    expression===nothing && return
    expression.action=="continue" || return
    event=configured_api_expression((id="api-expression:$now",actor=actor,role=:attention,text="",motion=nothing,appearances=String[]),now)
    for peer in IDS
        peer==actor && continue
        observation=role_public_observation(w,peer,yaw[peer],event;attending=peer in thinking)
        learn_observed_words!(CHANNEL_MEMORIES[peer].words,observation)
        observation===nothing || open(joinpath(OUTPUT,"api-heard.jsonl"),"a") do io
            println(io,JSON3.write((observer=peer,us=now,observation=observation)))
        end
    end
end
function configured_api_diary!(day,now,body,stock,notices)
    configured_api_diary_due(day) || return
    own_notices=[Dict(k=>get(n,k,nothing) for k in ("status","reason","us")) for n in notices]
    context=(day=day,own_body=(reserve=body.reserve,strain=body.strain,damage=body.damage),
        own_stock=configured_api_foods(stock),observations=copy(CONFIGURED_API_HISTORY),
        own_trade_notices=own_notices,remembered=CONFIGURED_API_MEMORY[])
    payload=(model=CONFIGURED_API_AGENT.model,store=false,max_output_tokens=700,
        instructions="あなたは個体Eです。今日は終わりました。本人が観測・体験したことだけを材料に、日本語で短い日記を書いてください。感想、相手への印象、未知の言葉の仮説、明日の意図も自由に。自分の推測と経験を区別し、未観測の相手の内心や成功を創作しないこと。自分の既存メモも誤り得ます。日記本文のみ。",
        input=configured_api_input((initial_knowledge=(CONFIGURED_API_BODY_LESSON,CONFIGURED_API_SURVIVAL_LESSON,CONFIGURED_API_INPUT_LESSON),experience=context)))
    write(joinpath(OUTPUT,"diary-request-$day.json"),JSON3.write(payload))
    buffer=IOBuffer();started=time()
    response=Downloads.request("https://api.openai.com/v1/responses";method="POST",
        headers=["Authorization"=>"Bearer "*ENV["OPENAI_API_KEY"],"Content-Type"=>"application/json"],
        input=IOBuffer(JSON3.write(payload)),output=buffer,timeout=120)
    raw=String(take!(buffer));write(joinpath(OUTPUT,"diary-response-$day.json"),raw)
    response.status==200 || error("diary API HTTP $(response.status)")
    result=JSON3.read(raw);result.status=="completed" || error("incomplete diary")
    diary=join([String(c.text) for o in result.output if o.type=="message" for c in o.content if c.type=="output_text"],"\n")
    write(joinpath(OUTPUT,"diary-$day.md"),diary)
    configured_api_record!((event="private_diary",day=day,us=now,text=diary,elapsed_seconds=time()-started))
end
configured_api_foods(xs)=Dict(CONFIGURED_API_FOODS[k]=>xs[k] for k in eachindex(xs) if xs[k]!=0)
function configured_api_record!(record)
    # API budgeting is operator diagnostics, never a sensation or memory of E.
    get(record,:event,nothing)=="configured_cap" || push!(CONFIGURED_API_HISTORY,deepcopy(record))
    open(joinpath(OUTPUT,"api-events.jsonl"),"a") do io;println(io,JSON3.write(record));end
    length(CONFIGURED_API_HISTORY)>CONFIGURED_API_AGENT.history_limit && popfirst!(CONFIGURED_API_HISTORY)
end
function configured_api_meal!(actor,kind,liking,now,before,after)
    actor==CONFIGURED_API_AGENT.actor || return
    if now<CONFIGURED_API_EDUCATION_DAYS*17_280_000_000
        configured_api_record!((event="naming_lesson",us=now,name=CONFIGURED_API_FOODS[kind],
            appearance=CONFIGURED_API_FORMS[kind],instruction="この外見の品目をこの呼称で呼ぶ。味は自分で食べて確かめる。"))
    end
    configured_api_record!((event="self_ate",us=now,food=CONFIGURED_API_FOODS[kind],experienced_liking=liking,
        own_reserve_before=before,own_reserve_after=after))
end
function configured_api_public!(observer,observation,scene,now)
    observer==CONFIGURED_API_AGENT.actor || return
    observation===nothing && scene===nothing && return
    configured_api_record!((event="perceived",us=now,
        text=observation===nothing ? nothing : observation.text,
        gesture=observation===nothing ? nothing : observation.motion,
        appearances=observation===nothing ? nothing : observation.appearances,
        observed_speaker=observation===nothing || !hasproperty(observation,:speaker) ? nothing : observation.speaker,
        observed_objects=observation===nothing || !hasproperty(observation,:objects) ? Any[] : observation.objects,
        transfers=observation===nothing || !hasproperty(observation,:transfers) ? Any[] : observation.transfers,scene=scene))
end
function configured_api_option(candidate,view,index)
    terms=get(candidate,"terms",nothing)
    if terms===nothing && haskey(candidate,"offer_id")
        incoming=filter(o->o["id"]==candidate["offer_id"],get(view,"incoming",Any[]))
        if !isempty(incoming)
            offer=first(incoming)
            terms=Dict("give_food"=>offer["want_food"],"want_food"=>offer["give_food"],
                "give_items"=>offer["want_items"],"want_items"=>offer["give_items"])
        end
    end
    (id=index,action=candidate["action"],partner=get(candidate,"partner",nothing),
        give=terms===nothing ? nothing : configured_api_foods(terms["give_food"]),
        receive=terms===nothing ? nothing : configured_api_foods(terms["want_food"]),
        give_objects=terms===nothing ? Int[] : terms["give_items"],
        receive_objects=terms===nothing ? Int[] : terms["want_items"])
end
function configured_api_choose!(loop,candidates,source,state,view,body,stock,now)
    state["actor"]==CONFIGURED_API_AGENT.actor || return choose_method!(loop,candidates,source)
    # Candidate order is lexical, never the hidden utility ranking.
    ordered=sort(copy(candidates);by=c->c["method"])
    day=div(now,17_280_000_000)+1 # existing LW 17280-second simulated day
    if get(CONFIGURED_API_CALLS,day,0)>=CONFIGURED_API_AGENT.calls_per_day || sum(values(CONFIGURED_API_CALLS);init=0)>=CONFIGURED_API_AGENT.total_calls
        safe=findfirst(c->c["action"] in ("continue","item_decline"),ordered)
        safe===nothing && error("API cap: no non-transfer action")
        configured_api_record!((event="configured_cap",us=now,action=ordered[safe]["action"]))
        return choose_method!(loop,[ordered[safe]],source)
    end
    notices=[Dict(k=>get(n,k,nothing) for k in ("status","reason","us")) for n in get(view,"notices",Any[])]
    context=(self=state["actor"],day=day,us=now,
        own_body=(reserve=body.reserve,strain=body.strain,damage=body.damage),
        own_stock=stock===nothing ? nothing : configured_api_foods(stock),
        observations=copy(CONFIGURED_API_HISTORY),own_trade_notices=notices,
        remembered=CONFIGURED_API_MEMORY[],options=[configured_api_option(c,view,i) for (i,c) in enumerate(ordered)])
    instructions="あなたは世界内の個体Eです。自分の観測・身体感覚・所持品・過去の経験だけが届きます。他者の内心や世界の評価式は知りません。生活し、体験から学び、他者と関わってください。初期教育は実際に食べた結果として与えます。未知の語句や動作の意味は観測から仮説を持てますが確定しないでください。自分のreserveはエネルギー残量、strainは疲労、damageは損傷です。味の数値はそのとき自分が感じたものです。optionsは操作候補で価値順ではありません。giveは自分から渡す、receiveは自分が受け取る物。item_offer提示,item_counter逆提案,item_accept承諾,item_decline拒否,continue継続。提示だけでは物は動かず相手の承諾が必要です。候補IDを一つ選びJSONのみで返してください: {\"choice\":整数,\"reason\":短い理由,\"memory\":次回保持する経験と未確定の仮説}。隠れた出来事を創作しない。memoryは2000文字以内。"
    instructions*=" JSONにはchoice, speech, gesture, reason, memoryの５欄を必ず含めてください。speechは短く。"*CONFIGURED_API_INPUT_LESSON
    payload=(model=CONFIGURED_API_AGENT.model,store=false,max_output_tokens=CONFIGURED_API_AGENT.output_tokens,
        text=(format=(type="json_object",),),instructions= instructions,
        input=configured_api_input((format_request="Return JSON with choice, speech, gesture, reason, memory.",input_fields=configured_api_input_fields(),initial_knowledge=(CONFIGURED_API_BODY_LESSON,CONFIGURED_API_SURVIVAL_LESSON,CONFIGURED_API_INPUT_LESSON),observation=context)))
    number=sum(values(CONFIGURED_API_CALLS);init=0)+1
    write(joinpath(OUTPUT,"api-request-$(number).json"),JSON3.write(payload))
    buffer=IOBuffer();started=time()
    response=Downloads.request("https://api.openai.com/v1/responses";method="POST",
        headers=["Authorization"=>"Bearer "*ENV["OPENAI_API_KEY"],"Content-Type"=>"application/json"],
        input=IOBuffer(JSON3.write(payload)),output=buffer,timeout=120)
    response_body=String(take!(buffer))
    if response.status!=200
        write(joinpath(OUTPUT,"api-error-$(number).json"),response_body)
        error("API HTTP $(response.status); no automatic retry")
    end
    result=JSON3.read(response_body);result.status=="completed" || error("incomplete API result")
    reply=join([String(c.text) for o in result.output if o.type=="message" for c in o.content if c.type=="output_text"],"\n")
    write(joinpath(OUTPUT,"api-response-$(number).json"),JSON3.write((reply,usage=result.usage,elapsed_seconds=time()-started)))
    decision=JSON3.read(reply)
    decision.choice isa Integer && 1<=decision.choice<=length(ordered) || error("invalid API choice; stop, no MB fallback")
    CONFIGURED_API_MEMORY[]=first(String(decision.memory),CONFIGURED_API_AGENT.memory_chars)
    CONFIGURED_API_CALLS[day]=get(CONFIGURED_API_CALLS,day,0)+1
    selected=ordered[Int(decision.choice)]
    String(decision.gesture) in CONFIGURED_API_GESTURES || error("invalid gesture")
    CONFIGURED_API_EXPRESSIONS[Int(now)]=(speech=String(decision.speech),gesture=String(decision.gesture),action=selected["action"])
    configured_api_record!((event="self_selected",us=now,option=context.options[Int(decision.choice)],reason=String(decision.reason)))
    # Existing loop trial bookkeeping and world execution stay authoritative.
    plan=choose_method!(loop,[selected],source)
    plan["selection_mode"]="configured_api"
    plan
end
