# Numerical accounting only: residuals never modify grass, intake or body state.
# Provisional Float64 budgets, in grass units. Warn well before a .025 bite
# can disappear at the cumulative volumes of the current long-run experiments.
function balance_diagnostic(name, supplied, accounted; previous=nothing)
    scale=max(abs(supplied),abs(accounted))
    residual=supplied-accounted
    warning_limit=1e-6+1e-10*scale
    stop_limit=1e-4+1e-8*scale
    finite=all(isfinite,(supplied,accounted,residual))
    status=!finite || abs(residual)>stop_limit ? "error" :
        abs(residual)>warning_limit ? "warning" : "ok"
    delta=previous===nothing ? nothing : residual-previous.residual
    peak=max(abs(residual),previous===nothing ? 0.0 : previous.max_abs_residual)
    diagnostic=(name=name,supplied=supplied,accounted=accounted,residual=residual,
        relative_error=scale==0 ? 0.0 : abs(residual)/scale,
        delta_since_previous=delta,max_abs_residual=peak,
        warning_limit=warning_limit,stop_limit=stop_limit,status=status)
    status=="error" && error("wildlife balance failure: $diagnostic")
    status=="warning" && @warn "wildlife balance warning" diagnostic
    diagnostic
end
