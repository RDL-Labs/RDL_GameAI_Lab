# Shared result assessment for a single forecasted interaction. Actual value is
# evaluated by the owner with the valuation frozen before the action; it is not
# another actor's value or a declaration that every remaining concern is solved.
function resolve_prediction!(s::BasicLoop,source,expected,actual;
        executed=true,observed=true,fulfilled=false,tolerance=.05,parent_expected=expected,parent_actual=actual)
    check(expected isa Real && !(expected isa Bool) && isfinite(expected),"prediction_expected")
    check(actual===nothing || (actual isa Real && !(actual isa Bool) && isfinite(actual)),"prediction_actual")
    check(all(x->x isa Bool,(executed,observed,fulfilled)),"prediction_evidence")
    check(!fulfilled || executed,"prediction_fulfillment_without_execution")
    check(tolerance isa Real && !(tolerance isa Bool) && isfinite(tolerance) && tolerance>=0,"prediction_tolerance")
    check(parent_expected isa Real && !(parent_expected isa Bool) && isfinite(parent_expected),"prediction_parent_expected")
    check(parent_actual===nothing || (parent_actual isa Real && !(parent_actual isa Bool) && isfinite(parent_actual)),"prediction_parent_actual")
    evidence=(kind="prediction",source=source,expected=Float64(expected),
        actual=actual===nothing ? nothing : Float64(actual),executed=executed,
        observed=observed,fulfilled=fulfilled,tolerance=Float64(tolerance),parent_expected=parent_expected,parent_actual=parent_actual)
    if s.receipt!==nothing && s.receipt.source==source
        check(s.receipt==evidence,"prediction_result_conflict")
        return false
    end
    check(s.trial!==nothing && s.trial.source==source,"prediction_result_binding")
    n=s.methods[s.trial.method];before=n.H;parent_before=s.H
    evaluated=executed && observed && actual!==nothing
    pressure=evaluated ? (s.h_mode==:forecast_difference ? max(0.,Float64(expected-actual-tolerance)) : max(0.,Float64(expected-actual-tolerance),Float64(-actual-tolerance))) : 0.
    benefit=evaluated && fulfilled ? max(0.,Float64(actual-tolerance)) : 0.
    parent_pressure=evaluated && parent_actual!==nothing ? max(0.,Float64(parent_expected-parent_actual-tolerance)) : nothing
    if evaluated
        # Relief is measured in the same owner-value units as the unmet forecast.
        # An arrival/result flag alone never erases the old parent or method H.
        if s.h_mode==:forecast_difference
            loop_forecast_difference!(s,s.trial.method,expected,actual;tolerance)
            loop_forecast_difference!(s,nothing,parent_expected,parent_actual;tolerance)
        else
            n.H=min(32.,max(0.,before-benefit)+pressure)
            s.H=min(32.,max(0.,parent_before-benefit)+pressure)
        end
        if s.h_mode==:forecast_difference
            # Partial subjective outcome only releases the measured residual;
            # an exchanged receipt is not proof of meeting all food needs.
            released=max(max(0.,before-n.H),max(0.,parent_before-s.H))
            benefit=fulfilled && actual>tolerance ? forecast_success_reward(expected>0 ? clamp(actual/expected,0.,1.) : 1.,released) : 0.
            benefit>0 && forecast_reward_record!(s.forecast_balances[s.trial.method],released,benefit)
        end
        n.reward+=benefit
        if pressure>0
            n.failure_count+=1;n.failure_H_total+=pressure
        end
    end
    credit=benefit>0 ? Dict(s.trial.method=>benefit) : Dict{String,Float64}()
    push!(s.events,(source=source,method=s.trial.method,question=s.trial.question,
        E=evaluated ? pressure : nothing,H_before=before,H_after=n.H,
        goal_E=s.h_mode==:forecast_difference ? parent_pressure : evaluated ? pressure : nothing,goal_H_before=parent_before,goal_H_after=s.H,
        goal_H_increment=s.h_mode==:forecast_difference ? max(0.,s.H-parent_before) : pressure,reward=benefit,credit=credit,failed=evaluated && pressure>0,
        failure_H=evaluated && pressure>0 ? pressure : nothing,
        expected=Float64(expected),actual=actual,evaluated=evaluated,fulfilled=fulfilled,
        relief=max(0.,parent_before-s.H),method_relief=max(0.,before-n.H),tolerance=Float64(tolerance),
        parent_expected=parent_expected,parent_actual=parent_actual))
    length(s.events)>32 && popfirst!(s.events)
    s.receipt=evidence;s.trial=nothing
    true
end
