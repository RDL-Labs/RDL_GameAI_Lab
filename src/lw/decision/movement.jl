# Candidate evaluation consumes observations, never the world.
struct EnergyMovementPolicy end
function evaluate_movement(::EnergyMovementPolicy,o)
    b=o.body;target=isempty(o.visible) ? nothing : o.visible[1]
    rows=Any[];chosen=nothing;best=Inf
    for sample in o.walks
        angle=sample.angle
        goal=target===nothing ? 1.0+abs(angle)/90 : min(10.,hypot(target["forward"]-cos(deg2rad(Float64(angle))),target["right"]-sin(deg2rad(Float64(angle)))))
        _,status,_,delta=step(b,"walk",o.load,sample.resistance,sample.clear)
        cost=status=="performed" ? goal-delta["reserve"]/max(b.reserve,.001)-delta["burst"]/max(b.burst,.001)+delta["strain"] : nothing
        if cost!==nothing && cost<best
            best=cost;chosen=sample.ref
        end
        push!(rows,D("ref"=>sample.ref,"action"=>"walk","clear"=>sample.clear,"resistance"=>sample.resistance,"load"=>o.load,"goal_cost"=>goal,
            "status"=>status,"cost"=>cost,"expected_delta"=>delta))
    end
    run_rows=Any[]
    for sample in o.runs
        _,status,d,delta=step(b,"run",o.load,sample.resistance,sample.clear)
        push!(run_rows,D("ref"=>sample.ref,"action"=>"run","clear"=>sample.clear,"resistance"=>sample.resistance,
            "load"=>o.load,"status"=>status,"cost"=>status=="performed" ? -delta["reserve"] : nothing,
            "distance"=>d,"expected_delta"=>delta))
    end
    D("movement_surface"=>D("schema"=>"l15a-current-surface-rays-v1",
        "ground"=>D("coverage"=>"complete","output_limited"=>false,"samples"=>o.surface)),
      "food_coverage"=>o.coverage,"run_rows"=>run_rows,"visible"=>o.visible,"energy"=>D("rule"=>"finite-energy-field-v1","rows"=>rows,"selected"=>chosen,
        "action"=>chosen===nothing ? "rest" : "walk","status"=>chosen===nothing ? "no_feasible_observed_move" : "selected"))
end
