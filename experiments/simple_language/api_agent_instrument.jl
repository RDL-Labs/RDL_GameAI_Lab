cp(joinpath(HERE,"../../src/lw/configured_paths/api_trade_agent.jl"),joinpath(OUTPUT,"source/src/lw/configured_paths/api_trade_agent.jl"))
api_path=joinpath(OUTPUT,"source/src/lw/decision/item_social.jl")
api_text=read(api_path,String)
@assert length(findall("plan=choose_method!(loop,candidates,source)",api_text))==1
write(api_path,replace(api_text,"plan=choose_method!(loop,candidates,source)"=>"plan=configured_api_choose!(loop,candidates,source,state,view,body,stock,now)"))
api_day=joinpath(OUTPUT,"source/src/lw/simulation/day.jl")
api_text=read(api_day,String)
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
write(api_day,replace(api_text,marker=>marker*"\n                    configured_api_meal!(a,actual_kind,liking,now,premeal.reserve,w.bodies[a].reserve)"))
api_channels=joinpath(OUTPUT,"communication/trade_channels.jl")
api_text=read(api_channels,String)
marker="        if status==\"offered\""
@assert length(findall(marker,api_text))==1
write(api_channels,replace(api_text,marker=>"        configured_api_public!(observer,observation,scene,now)\n"*marker))
include(joinpath(OUTPUT,"source/src/lw/configured_paths/api_trade_agent.jl"))
