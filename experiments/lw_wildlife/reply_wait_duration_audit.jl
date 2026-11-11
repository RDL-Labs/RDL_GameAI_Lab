using JSON3, Serialization
const root=abspath(ARGS[1])
include(joinpath(root,"source/src/lw/LW.jl"))
state=deserialize(joinpath(root,"run/checkpoints/day-060.jls")).state
episodes=Any[];morning=0
for actor in LW.IDS
    events=filter(e->get(e,"actor",nothing)==actor,state[:events])
    started=nothing
    for e in events
        global morning
        rule=get(e,"configured_rule",nothing)
        morning+=Int(rule=="scheduled_orientation")
        if rule=="pending_social_reply"
            started===nothing && (started=e["us"])
        elseif started!==nothing
            push!(episodes,(actor,day=div(started,17_280_000_000)+1,second=mod(started,17_280_000_000)/1e6,
                seconds=(e["us"]-started)/1e6,next_action=e["action"]))
            started=nothing
        end
    end
    @assert started===nothing "unfinished final wait"
end
result=(episodes=length(episodes),max_seconds=isempty(episodes) ? 0. : maximum(e.seconds for e in episodes),
    mean_seconds=isempty(episodes) ? 0. : sum(e.seconds for e in episodes)/length(episodes),
    over_five=count(e->e.seconds>5,episodes),morning_fixed_events=morning,
    histogram=Dict(string(t)=>count(e->e.seconds==t,episodes) for t in sort(unique(e.seconds for e in episodes))),
    longest=sort(episodes,by=e->-e.seconds)[1:min(10,length(episodes))])
write(ARGS[2],JSON3.write(result));println(JSON3.write(result))
