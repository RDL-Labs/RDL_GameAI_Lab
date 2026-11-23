# 暫定固定: API field_training runner only. A staged curriculum, not a learned goal.
# Camp tour and eating/processing use existing scaffolds; outbound/return E navigation
# stays API-controlled. Teacher samples are handed over at home once per lesson.
# Replace this teacher-imposed curriculum with observed instruction in future.
configured_api_fish_active(q)=!(q["stage"] in ("waiting_acorn","completed"))
const CONFIGURED_API_TRAINING_OBSERVATION_US=Ref(-600_000_000)
function configured_api_training_report!(maps,day,now)
    configured_api_training_observe!(CONFIGURED_API_AGENT.actor,maps[CONFIGURED_API_AGENT.actor],now)
    report=Dict(actor=>Dict("acorn"=>map["training_quest"],"fishing"=>map["fishing_training"]) for (actor,map) in maps)
    write(joinpath(OUTPUT,"field-training-progress.json"),JSON3.write((day=day,actors=report)))
end
function configured_api_training_supply!(maps,day,now,day_us)
    supply=Dict{String,Any}()
    for actor in sort!(collect(keys(maps)))
        map=maps[actor];fish=map["fishing_training"]
        if fish["stage"]=="waiting_acorn" && configured_acorn_quest_released(map["training_quest"],now,day_us)
            fish["stage"]="taste"
        end
    end
    supply
end
# 暫定固定: field_training only (ordinary LW OFF). A teacher robot at home
# hands one fruit/fish sample to each learner at the corresponding stage.
# This world-side supply is recorded, not a learned production or social action.
# Replace with instruction/physical teacher interaction later. Persistent lesson
# records prevent duplicate grants after restore; missing granted food pauses teaching.
function configured_api_teacher_handover!(map,foods,w,cargo,ledger,actor,at_home,now)
    at_home || return 0
    quest=map["training_quest"];fish=map["fishing_training"]
    lesson=quest["stage"]=="taste_fruit" ? "fruit" : fish["stage"]=="taste" ? "fish" : nothing
    lesson===nothing && return 0
    grants=get!(()->Dict{String,Any}(),map,"teacher_grants")
    haskey(grants,lesson) && return 0
    kind=lesson=="fruit" ? 1 : Int(RDLBody.FISH_FOOD)
    deadline=food_deadline(foods,kind)
    food_push!(foods,actor,kind;deadline)
    foods.added[kind]+=1;w.inventory[actor]+=1;push!(cargo[actor],nothing)
    record=D("source"=>"teacher_robot","lesson"=>lesson,"actor"=>actor,
             "kind"=>kind,"added"=>1,"us"=>now,"deadline"=>deadline)
    grants[lesson]=copy(record);push!(ledger,record)
    actor==CONFIGURED_API_AGENT.actor && configured_api_record!((event="teacher_handover",us=now,food=CONFIGURED_API_FOODS[kind],quantity=1))
    1
end
function configured_api_training_available_plan(q,plan,inventory,stock,now)
    plan===nothing && return nothing
    if get(plan,"action",nothing)=="retrieve"
        kind=Int(plan["food_kind"])
        if !(kind in inventory) && stock[kind]<=0
            get(q,"material_wait",false) || push!(q["records"],D("kind"=>"teacher_material_unavailable","us"=>now,"food_kind"=>kind))
            q["material_wait"]=true
            return nothing
        end
    end
    q["material_wait"]=false
    plan
end
function configured_api_training_observe!(actor,map,now;observed=nothing,heading=nothing)
    actor==CONFIGURED_API_AGENT.actor || return
    quest=map["training_quest"];fish=map["fishing_training"]
    stage=quest["stage"]!="completed" ? "acorn:"*quest["stage"] : "fishing:"*fish["stage"]
    instructions=Dict(
        "acorn:learn_home"=>"拠点を見学し、見た特徴と移動・帰還の関係を経験する。見学は教師が案内する。",
        "acorn:outbound"=>"拠点の外で殻付きの茶色い実を探し、2個採取して持ち帰る。観測できた手がかりで移動を選ぶ。",
        "acorn:return"=>"採取した実を拠点へ持ち帰り、倉庫へ置く。",
        "acorn:taste_raw"=>"持ち帰った生ドングリを実食し、味を経験する。",
        "acorn:process"=>"拠点の加工所で残りの生ドングリを加工する。",
        "acorn:taste_processed"=>"加工ドングリを実食して違いを経験する。",
        "acorn:taste_fruit"=>"果実も実食して比べる。",
        "fishing:waiting_acorn"=>"次の朝から魚の研修を始める。",
        "fishing:taste"=>"研修用の生魚1個を拠点で加工し、食べる。これは一度限りの試食品で、生活用補充はない。",
        "fishing:trial"=>"川の釣り場を観測から探し、釣りを一度試して帰る。釣れなくても課題は成立する。",
        "fishing:return"=>"釣りを試したので拠点へ帰る。",
        "fishing:completed"=>"研修修了。自動補充なしで通常生活を行う。")
    lesson=(stage=stage,instruction=get(instructions,stage,"研修課題を継続する。"),completed=stage=="fishing:completed")
    if CONFIGURED_API_LESSON[]===nothing || CONFIGURED_API_LESSON[].stage!=stage
        configured_api_record!((event="teacher_task",us=now,lesson=lesson))
    end
    CONFIGURED_API_LESSON[]=lesson
    if observed!==nothing && !lesson.completed && now-CONFIGURED_API_TRAINING_OBSERVATION_US[]>=600_000_000
        configured_api_record!((event="training_observation",us=now,stage=stage,heading=heading,observed=observed))
        CONFIGURED_API_TRAINING_OBSERVATION_US[]=now
    end
end
