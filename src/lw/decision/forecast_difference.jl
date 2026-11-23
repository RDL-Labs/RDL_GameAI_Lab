# Each MB owns its forecast/observation ledger. Inputs are increments in the
# owner's valuation units, not another MB's H. Signed observations allow losses.
const H_RELEASE_REWARD=(success_base=.1,release_gain=1.) # Provisional subjective units; local probe calibration.
forecast_success_reward(progress,released)=H_RELEASE_REWARD.success_base*progress+H_RELEASE_REWARD.release_gain*released
function forecast_reward_record!(balance,released,reward)
    balance["released_total"]=get(balance,"released_total",0.)+released
    balance["reward_total"]=get(balance,"reward_total",0.)+reward
    balance["reward_events"]=get(balance,"reward_events",0)+1
end
function loop_release_H!(loop,key,amount)
    check(amount isa Real && !(amount isa Bool) && isfinite(amount) && amount>=0,"release_amount")
    current=key===nothing ? loop.H : loop.methods[key].H
    released=min(current,Float64(amount))
    loop_forecast_difference!(loop,key,0.,released)
    released
end
forecast_difference_state(initial_H=0.)=D("expected"=>Float64(initial_H),"observed"=>0.,"H"=>Float64(initial_H))
function forecast_difference!(state,expected,observed;tolerance=0.)
    (expected===nothing || observed===nothing) && return false
    check(all(x->x isa Real && !(x isa Bool) && isfinite(x),(expected,observed,tolerance)) && tolerance>=0,"forecast_difference_input")
    next_expected=state["expected"]+expected;next_observed=state["observed"]+observed
    check(isfinite(next_expected) && isfinite(next_observed),"forecast_difference_overflow")
    state["expected"]=next_expected;state["observed"]=next_observed
    # Apply the tolerance to the total residual, never discard each small increment.
    state["H"]=max(0.,next_expected-next_observed-tolerance)
    true
end
function loop_forecast_difference!(loop,key,expected,observed;tolerance=0.)
    (expected===nothing || observed===nothing) && return false
    initial=key===nothing ? loop.H : loop.methods[key].H
    state=get!(() -> forecast_difference_state(initial),loop.forecast_balances,key)
    forecast_difference!(state,expected,observed;tolerance) || return false
    key===nothing ? (loop.H=state["H"]) : (loop.methods[key].H=state["H"])
    true
end
