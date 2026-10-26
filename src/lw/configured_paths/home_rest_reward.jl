# Removable experimental value, not learned intrinsic place preference.
configured_home_rest_state()=D("day"=>-1,"seconds"=>0,"awarded"=>false,
    "last_us"=>nothing,"arrival"=>nothing,"reward_total"=>0.,"records"=>Any[])
function configured_home_rest_arrival!(s,loop,source,now)
    state=get!(() -> configured_home_rest_state(),s,"configured_home_rest_reward")
    state["arrival"]!==nothing && return # Keep this visit's arrival, not later local steps.
    methods=isempty(loop.events) ? String[] : collect(keys(last(loop.events).credit))
    route=nothing;chunk=nothing
    events=s["routes"]["events"]
    if !isempty(events)
        e=last(events)
        e["goal"]=="home" && e["outcome"]=="success" && e["ended_us"]==now && (route=e["id"])
    end
    records=s["chunk_records"]
    if !isempty(records)
        e=last(records)
        e["goal"]=="home" && e["source"]==source && (chunk=e["chunk"])
    end
    state["arrival"]=D("source"=>source,"methods"=>methods,"route"=>route,"chunk"=>chunk)
end
function configured_home_rest_step!(s,loop,at_home,action,status,now,day_us)
    state=get!(() -> configured_home_rest_state(),s,"configured_home_rest_reward")
    state["last_us"]!==nothing && now<=state["last_us"] && return 0.
    continuous=state["last_us"]!==nothing && now==state["last_us"]+1_000_000
    state["last_us"]=now
    day=div(now,day_us)
    if state["day"]!=day
        state["day"]=day;state["seconds"]=0;state["awarded"]=false
    end
    if !at_home
        state["seconds"]=0;state["arrival"]=nothing;return 0.
    end
    if action!="rest" || status!="performed"
        state["seconds"]=0;return 0.
    end
    !continuous && (state["seconds"]=0)
    state["seconds"]+=1
    (state["awarded"] || state["seconds"]<60) && return 0.
    # Once per actor/day: brief departure, re-entry or repeated receipts cannot farm it.
    reward=5.;state["awarded"]=true;state["reward_total"]+=reward
    arrival=state["arrival"];credit=D()
    if arrival!==nothing
        methods=filter(k->haskey(loop.methods,k),arrival["methods"])
        for k in methods
            loop.methods[k].reward+=reward/length(methods);credit[k]=reward/length(methods)
        end
        id=arrival["route"];r=id===nothing ? nothing : get(s["routes"]["stats"],id,nothing)
        r!==nothing && (r["reward"]+=reward;r["rest_reward"]=get(r,"rest_reward",0.)+reward)
        id=arrival["chunk"];c=id===nothing ? nothing : get(s["chunks"],id,nothing)
        if c!==nothing
            c["reward"]+=reward;c["rest_reward"]=get(c,"rest_reward",0.)+reward;s["chunk_reward"]+=reward
        end
    end
    push!(state["records"],D("us"=>now,"day"=>day,"reward"=>reward,"arrival"=>deepcopy(arrival),"credit"=>credit))
    length(state["records"])>32 && popfirst!(state["records"])
    reward
end
