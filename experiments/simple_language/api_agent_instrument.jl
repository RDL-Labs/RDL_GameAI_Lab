cp(joinpath(HERE,"../../src/lw/configured_paths/api_transport.jl"),joinpath(OUTPUT,"source/src/lw/configured_paths/api_transport.jl");force=true)
cp(joinpath(HERE,"../../src/lw/configured_paths/api_trade_agent.jl"),joinpath(OUTPUT,"source/src/lw/configured_paths/api_trade_agent.jl"))
if API_EXPLORATION
    standard=JSON3.read(read(API_STANDARD_INPUT,String),Dict{String,Any})
    for key in ("food","regrowth_days","regrowth_capacity","ground")
        haskey(standard["config"],key) && (input["config"][key]=standard["config"][key])
    end
    initial_stock=Int(first(standard["scene"]["initial_personal_stock"]))
    input["scene"]["initial_personal_stock"]=fill(initial_stock,5)
    for actor in input["scene"]["experimental_actor_ids"]
        input["scene"]["initial_personal_food_counts"][actor]=[initial_stock,0,0,0,0,0,0,0]
    end
    # Keep the tested communication/identity setup; restore standard world resources.
    for key in ("food","ground_patches","food_season","obstacles","low_obstacles","landscape","food_facilities","visual_landmarks","home")
        haskey(standard["scene"],key) && (input["scene"][key]=deepcopy(standard["scene"][key]))
    end
    input["scene"]["configured_trade_living"]=false
    input["scene"]["name"]="API exploration: standard resources, no daily supply"
    # Education portions only; no replenishment after the three tasting days.
    for row in values(input["scene"]["personal_food_supply"]);row["quantity"]=1;end
    if API_FIELD_TRAINING
        include(joinpath(HERE,"api_field_training_instrument.jl"))
        api_field_training_input!(input)
    end
    write(joinpath(OUTPUT,"input.json"),JSON3.write(input))
end
for (i,actor) in enumerate(input["scene"]["experimental_actor_ids"])
    @assert sum(input["scene"]["initial_personal_food_counts"][actor])==input["scene"]["initial_personal_stock"][i]
end
api_path=joinpath(OUTPUT,"source/src/lw/decision/item_social.jl")
api_text=read(api_path,String)
@assert length(findall("plan=choose_method!(loop,candidates,source)",api_text))==1
@assert length(findall("        isempty(candidates) && return nothing",api_text))==1
# 暫定固定: E may speak/gesture while continuing even with no acceptable trade.
# This does not add a gift, force a reply, or bypass ownership constraints.
api_text=replace(api_text,"        isempty(candidates) && return nothing"=>"        isempty(candidates) && state[\"actor\"]!=\"npc_e\" && return nothing")
write(api_path,replace(api_text,"plan=choose_method!(loop,candidates,source)"=>"plan=configured_api_choose!(loop,candidates,source,state,view,body,stock,now)"))
api_day=joinpath(OUTPUT,"source/src/lw/simulation/day.jl")
api_text=read(api_day,String)
if API_EXPLORATION
    supply_marker="            replenished+=configured_personal_food_supply!"
    @assert length(findall(supply_marker,api_text))==1
    api_text=replace(api_text,supply_marker=>"            day>=3 && (personal_supply=nothing)\n"*supply_marker)
    nav_marker="                            plan=choose_method!(s,candidates,source)"
    @assert length(findall(nav_marker,api_text))==1
    api_text=replace(api_text,nav_marker=>"                            plan=configured_api_navigation!(a,s,candidates,source,w.bodies[a],foods.personal[a],now,yaw[a],landmarks===nothing ? nothing : landmarks[a];navigation_context=(purpose=family,phase=phase,observed_target=target,observed_moves=moves[a]),budget_capture=()->@lw_capture())")
    result_marker="            counts[a][action]=get(counts[a],action,0)+1"
    @assert length(findall(result_marker,api_text))==1
    api_text=replace(api_text,result_marker=>"            configured_api_nav_result!(a,action,status,now)\n"*result_marker)
    # Keep ordinary gradient-roll enrollment, continuation and reconsideration for E too.
    cp(joinpath(HERE,"../../src/lw/configured_paths/api_navigation.jl"),joinpath(OUTPUT,"source/src/lw/configured_paths/api_navigation.jl"))
end
stop_marker="        advance_physiology!(w,metabolism,guts,food_body)"
@assert length(findall(stop_marker,api_text))==1
api_text=replace(api_text,stop_marker=>"        configured_api_check_stop!(w.bodies[\"npc_e\"],now+1_000_000,()->@lw_capture();phase=\"after_actions\")\n"*stop_marker*"\n        configured_api_check_stop!(w.bodies[\"npc_e\"],now+1_000_000,()->@lw_capture();phase=\"after_physiology\")")
if API_SCARCE
    supply_marker="            replenished+=configured_personal_food_supply!"
    @assert length(findall(supply_marker,api_text))==1
    api_text=replace(api_text,supply_marker=>"            personal_supply=configured_api_supply(personal_supply,day)\n"*supply_marker)
    aid_marker="            elseif (relations!==nothing ? forecast_request_ready :"
    @assert length(findall(aid_marker,api_text))==1
    api_text=replace(api_text,aid_marker=>"            elseif configured_api_aid_allowed() && (relations!==nothing ? forecast_request_ready :")
    visual_marker="                plan=visual_aid_plan!("
    @assert length(findall(visual_marker,api_text))==1
    api_text=replace(api_text,visual_marker=>"                plan=configured_api_aid_allowed() ? visual_aid_plan!(")
    ending="kinds,now;at_home,contacts=o[\"others\"])"
    @assert length(findall(ending,api_text))==1
    api_text=replace(api_text,ending=>ending*" : nothing")
end
cp(joinpath(HERE,"../../src/lw/decision/task_focus.jl"),joinpath(OUTPUT,"source/src/lw/decision/task_focus.jl");force=true)
# Same received-trade wake bridge as cohort WANT_VOICE; independent of speech.
if !occursin("task_trade_notice!",api_text)
    wake_marker="            notice=get(fs,\"active\",false) && focus_enabled"
    @assert length(findall(wake_marker,api_text))==1
    wake_code="            item_pending=incidental_items===nothing ? nothing : get(get(incidental_items[a],\"social\",D()),\"pending\",nothing)\n            trade_notice=item_exchange_enabled ? task_trade_notice!(fs,items,w,a,now;pending_offer=item_pending===nothing ? nothing : item_pending[\"offer_id\"]) : nothing\n"
    api_text=replace(api_text,wake_marker=>wake_code*wake_marker)
    wake_old="wait_notice=identity_call_notice===nothing ? task_wait_notice(fs,w.inbox[a],now) : identity_call_notice,"
    @assert length(findall(wake_old,api_text))==1
    api_text=replace(api_text,wake_old=>"wait_notice=trade_notice!==nothing ? trade_notice : identity_call_notice===nothing ? task_wait_notice(fs,w.inbox[a],now) : identity_call_notice,")
end
marker="                    eaten_kind=actual_kind;meal_liking=liking"
@assert length(findall(marker,api_text))==1
# Explicit local public handover display, only after actual aid transfer succeeds.
aid_transfer_marker="                if relations!==nothing && action in (\"give\",\"refuse\")"
@assert length(findall(aid_transfer_marker,api_text))==1
api_text=replace(api_text,aid_transfer_marker=>"                action==\"give\" && status==\"transferred\" && configured_api_aid_transfer!(w,yaw,thinking_ids,a,get(plan,\"target\",nothing),delivered_kind,now)\n"*aid_transfer_marker)
execution_marker="            plan=plans[a];action=plan[\"action\"];"
@assert length(findall(execution_marker,api_text))==1
api_text=replace(api_text,execution_marker=>"            configured_api_continue_expression!(a,w,yaw,thinking_ids,now)\n"*execution_marker)
binding_marker="        trade_views=trades===nothing"
@assert length(findall(binding_marker,api_text))==1
api_text=replace(api_text,binding_marker=>"        bind_utterance_context!(relations,CHANNEL_MEMORIES,items,spec.home,now,yaw)\n"*binding_marker)
diary_marker="            checkpoint_dir!==nothing && checkpoint_save"
@assert length(findall(diary_marker,api_text))==1
api_text=replace(api_text,diary_marker=>"            configured_api_diary!(length(daily),now,w.bodies[\"npc_e\"],foods.personal[\"npc_e\"],items[\"notices\"][\"npc_e\"])\n"*diary_marker)
if API_FIELD_TRAINING
    daily_marker="            configured_api_diary!(length(daily),now,"
    api_text=replace(api_text,daily_marker=>"            configured_api_nav_flush!(now)\n            configured_api_training_report!(mb_maps,length(daily),now)\n"*daily_marker)
end
api_text=replace(api_text,marker=>marker*"\n                    configured_api_meal!(a,actual_kind,liking,now,body_energy(premeal),body_energy(w.bodies[a]))")
API_FIELD_TRAINING && (api_text=api_field_training_instrument(api_text))
write(api_day,api_text)
api_channels=joinpath(OUTPUT,"communication/trade_channels.jl")
api_text=read(api_channels,String)
event_marker="    for (observer,settings) in observers"
@assert length(findall(event_marker,api_text))==1
api_text=replace(api_text,event_marker=>"    event=configured_api_expression(event,now)\n"*event_marker)
observation_marker="        learn_observed_words!(memory.words,observation)"
api_text=replace(api_text,observation_marker=>"        if actor==\"npc_e\" && observation!==nothing\n            open(joinpath(OUTPUT,\"api-heard.jsonl\"),\"a\") do io;println(io,JSON3.write((observer=observer,us=now,observation=observation)));end\n        end\n"*observation_marker)
marker="        if status==\"offered\""
@assert length(findall(marker,api_text))==1
write(api_channels,replace(api_text,marker=>"        configured_api_public!(observer,observation,scene,now)\n"*marker))
include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_trade_agent.jl"))
API_EXPLORATION && include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_navigation.jl"))
if API_FIELD_TRAINING
    cp(joinpath(HERE,"../../src/lw/configured_paths/api_field_training.jl"),joinpath(OUTPUT,"source/src/lw/configured_paths/api_field_training.jl"))
    include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_field_training.jl"))
end
