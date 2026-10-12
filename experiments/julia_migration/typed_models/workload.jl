# Included unchanged into baseline and typed modules. No serialization in timings.
function workload(n,trace=false)
    records=Records();pressure=nothing;history=Any[];selection=nothing
    for i in 1:n
        id=string(i);target=isodd(i) ? "b" : "c"
        outcome=i%7==0 ? "request_not_executed" : i%3==0 ? "given" : "refuse"
        records[id]=D("agent_id"=>"a","target"=>target,"outcome"=>outcome,
            "request_observation_id"=>"request:"*id,"source_observation_id"=>"result:"*id)
        pressure=pressure_update(pressure,records,"a",3)
        selection=select_target(["c","b"],D(),pressure)
        trace && push!(history,D("pressure"=>deepcopy(pressure),"selection"=>deepcopy(selection)))
    end
    (pressure,selection,history)
end
