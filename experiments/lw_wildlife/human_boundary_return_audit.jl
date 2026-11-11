using JSON3,Serialization
const root=abspath(ARGS[1])
include(joinpath(root,"source/src/lw/LW.jl"))
input=JSON3.read(read(joinpath(root,"source/input.json"),String),Dict{String,Any})
home=input["scene"]["home"];day_us=input["clock"]["day_us"]
output=Dict{String,Any}()
for mode in ("baseline","boxes")
    saved=deserialize(joinpath(root,mode,"checkpoints/day-030.jls"))
    state=saved.state;actors=Dict{String,Any}()
    for actor in LW.IDS
        map=state[:mb_maps][actor]
        delivery=map["configured_daily_delivery"]
        plan=map["daily_plan"]
        day_ends=Any[]
        for (day,record) in enumerate(state[:daily])
            physical=record["physical"][actor];position=physical["position"]
            distance=hypot(position[1]-home[1],position[2]-home[2])
            push!(day_ends,(day,distance,at_home=distance<=1.25,reserve=physical["body"]["reserve"],inventory=physical["inventory"]))
        end
        deposits=[e for e in state[:events] if get(e,"actor",nothing)==actor && get(e,"action",nothing)=="deposit"]
        local_returns=get(plan,"local_returns",Any[])
        outside_days=[r.day for r in day_ends if !r.at_home]
        outside_events=Dict(string(day)=>[e for e in state[:events] if get(e,"actor",nothing)==actor && div(e["us"],day_us)+1==day] for day in outside_days)
        actors[actor]=Dict("counter"=>state[:purposes][actor]["completed"],
            "delivery_days"=>sort(unique(div(r["us"],day_us)+1 for r in delivery["records"])),
            "delivery_records"=>delivery["records"],"delivery_completions"=>delivery["completions"],
            "day_ends"=>day_ends,"deposit_events"=>deposits,
            "outside_day_events"=>outside_events,
            "plan_records"=>plan["records"],"local_returns"=>local_returns,
            "local_returns_capped"=>length(local_returns)>=128,
            "plan_records_capped"=>length(plan["records"])>=128)
        println(JSON3.write((mode,actor,counter=actors[actor]["counter"],delivery_days=actors[actor]["delivery_days"],
            outside_day_ends=[r.day for r in day_ends if !r.at_home],
            plan_returns=count(r->r["returned"],plan["records"]),local_returns=length(local_returns),
            local_returns_capped=length(local_returns)>=128,deposit_event_count=length(deposits))))
    end
    output[mode]=actors
    saved=nothing;state=nothing;GC.gc()
end
write(ARGS[2],JSON3.write(output))
