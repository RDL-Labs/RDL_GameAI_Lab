# Shared result assessment for a single forecasted interaction. Actual value is
# evaluated by the owner with the valuation frozen before the action; it is not
# another actor's value or a declaration that every remaining concern is solved.
function resolve_prediction!(s::BasicLoop,source,expected,actual;
        executed=true,observed=true,fulfilled=false,tolerance=.05)
    check(expected isa Real && !(expected isa Bool) && isfinite(expected),"prediction_expected")
    check(actual===nothing || (actual isa Real && !(actual isa Bool) && isfinite(actual)),"prediction_actual")
    check(all(x->x isa Bool,(executed,observed,fulfilled)),"prediction_evidence")
    check(!fulfilled || executed,"prediction_fulfillment_without_execution")
    check(tolerance isa Real && !(tolerance isa Bool) && isfinite(tolerance) && tolerance>=0,"prediction_tolerance")
    evidence=(kind="prediction",source=source,expected=Float64(expected),
        actual=actual===nothing ? nothing : Float64(actual),executed=executed,
        observed=observed,fulfilled=fulfilled,tolerance=Float64(tolerance))
    if s.receipt!==nothing && s.receipt.source==source
        check(s.receipt==evidence,"prediction_result_conflict")
        return false
    end
    check(s.trial!==nothing && s.trial.source==source,"prediction_result_binding")
    n=s.methods[s.trial.method];before=n.H;parent_before=s.H
    evaluated=executed && observed && actual!==nothing
    pressure=evaluated ? max(0.,Float64(expected-actual-tolerance),Float64(-actual-tolerance)) : 0.
    benefit=evaluated && fulfilled ? max(0.,Float64(actual-tolerance)) : 0.
    if evaluated
        # Relief is measured in the same owner-value units as the unmet forecast.
        # An arrival/result flag alone never erases the old parent or method H.
        n.H=min(32.,max(0.,before-benefit)+pressure)
        s.H=min(32.,max(0.,parent_before-benefit)+pressure)
        n.reward+=benefit
        if pressure>0
            n.failure_count+=1;n.failure_H_total+=pressure
        end
    end
    credit=benefit>0 ? Dict(s.trial.method=>benefit) : Dict{String,Float64}()
    push!(s.events,(source=source,method=s.trial.method,question=s.trial.question,
        E=evaluated ? pressure : nothing,H_before=before,H_after=n.H,
        goal_E=evaluated ? pressure : nothing,goal_H_before=parent_before,goal_H_after=s.H,
        goal_H_increment=pressure,reward=benefit,credit=credit,failed=evaluated && pressure>0,
        failure_H=evaluated && pressure>0 ? pressure : nothing,
        expected=Float64(expected),actual=actual,evaluated=evaluated,fulfilled=fulfilled,
        relief=min(parent_before,benefit),method_relief=min(before,benefit),tolerance=Float64(tolerance)))
    length(s.events)>32 && popfirst!(s.events)
    s.receipt=evidence;s.trial=nothing
    true
end
