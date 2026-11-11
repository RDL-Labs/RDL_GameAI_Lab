using JSON3, Serialization
const root=abspath(ARGS[1]);const output=abspath(ARGS[2])
include(joinpath(root,"source/src/lw/LW.jl"))
state=deserialize(joinpath(root,"run/checkpoints/day-060.jls")).state
day_us=17_280_000_000
rules=Dict{String,Int}();transitions=Any[];work_interrupts=Any[]
for actor in LW.IDS
    events=filter(e->get(e,"actor",nothing)==actor,state[:events])
    for i in eachindex(events)
        e=events[i];rule=get(e,"configured_rule",nothing)
        method=get(e,"method",nothing)
        rule===nothing && method in ("configured_post_return_idle","sleep_external_gate") && (rule=method)
        rule===nothing && continue
        rules[rule]=get(rules,rule,0)+1
        i==1 && continue
        p=events[i-1]
        stop=i<length(events) ? events[i+1]["us"] : 60day_us
        row=(actor,day=div(e["us"],day_us)+1,second=mod(e["us"],day_us)/1e6,
            rule,action=e["action"],previous_action=p["action"],previous_status=get(p,"status",nothing),
            previous_method=get(p,"method",nothing),purpose=get(e,"purpose_family",nothing),
            previous_purpose=get(p,"purpose_family",nothing),event_span_seconds=(stop-e["us"])/1e6)
        p["action"]!=e["action"] && push!(transitions,row)
        p["action"] in ("fish","process_food") && get(p,"status",nothing) in ("fishing","processing") &&
            e["action"]!=p["action"] && push!(work_interrupts,row)
    end
end
focus=Dict(a=>get(state[:mb_maps][a]["task_focus"],"wakeups",nothing) for a in LW.IDS)
configured=Dict(a=>Dict(k=>v for (k,v) in state[:mb_maps][a] if k in ("configured_post_return_idle","configured_trade_idle","sleep_gate")) for a in LW.IDS)
trade_wait=Dict(a=>get(state[:incidental_items][a],"configured_work_wait",nothing) for a in LW.IDS)
counts=Dict{String,Int}()
for r in transitions;counts[r.rule]=get(counts,r.rule,0)+1;end
samples=Dict(rule=>sort(filter(r->r.rule==rule,transitions),by=r->-r.event_span_seconds)[1:min(8,n)] for (rule,n) in counts)
prior_actions=Dict(rule=>Dict(action=>count(r->r.rule==rule && r.previous_action==action,transitions)
    for action in unique(r.previous_action for r in transitions if r.rule==rule)) for rule in keys(counts))
result=(days=60,rule_event_counts=rules,action_transition_counts=counts,work_interrupts,focus_wakeups=focus,
    samples,prior_actions,
    longest_transitions=sort(transitions,by=r->-r.event_span_seconds)[1:min(30,length(transitions))],
    configured_states=configured,trade_wait)
write(output,JSON3.write(result))
println(JSON3.write((prior_actions,samples=Dict(k=>v for (k,v) in samples if k in ("scheduled_orientation","quiet_night","wait_before_trade_offer","pending_social_reply")))))
