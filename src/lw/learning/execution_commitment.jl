# Selection is retained until relevant evidence calls for another comparison.
# This helper neither selects an action nor updates H/rewards. Callers supply
# their own scope, forecast and observed evidence; visibility loss is not a reason.
if !isdefined(@__MODULE__, :execution_commitment)
function execution_commitment(key,now,seconds;context=nothing,pressure=0.)
    isfinite(seconds) && seconds>=0 || error("invalid execution forecast")
    D("key"=>key,"started_us"=>now,"review_us"=>now+ceil(Int,max(1.,seconds)*1_000_000),
      "context"=>deepcopy(context),"pressure"=>Float64(pressure))
end
function execution_review_reason(c,now;key=c===nothing ? nothing : c["key"],
        context=c===nothing ? nothing : c["context"],pressure=c===nothing ? 0. : c["pressure"],
        completed=false,interrupted=false,contradiction=false)
    c===nothing && return "unselected"
    completed && return "completed"
    interrupted && return "interrupted"
    key!=c["key"] && return "scope_changed"
    contradiction && return "contradicted"
    context!=c["context"] && return "evidence_changed"
    pressure>c["pressure"] && return "pressure_increased"
    now>=c["review_us"] && return "forecast_elapsed"
    nothing
end
end
