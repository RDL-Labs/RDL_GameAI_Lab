module HReleaseRewardProbe
# Local experiment only. Progress is owner-assessed evidence supplied by the
# fixture, not omniscient success and not inferred from a child's success.
const D=Dict{String,Any}
check(ok,message)=ok || throw(ArgumentError(message))
include("../../src/lw/decision/forecast_difference.jl")

# Provisional subjective units: compare mechanics, not tuned living behavior.
const REWARD_RULES=(success_base=.1,release_gain=1.)
mutable struct Trial
    balance::D
    progress::Float64
    status::Symbol
    contributors::Dict{String,Float64}
    receipts::Dict{String,Any}
    released::Float64
    reward::Float64
end
mutable struct Mind
    trials::Dict{String,Trial}
    strength::Dict{String,Float64}
end
Mind()=Mind(Dict{String,Trial}(),Dict{String,Float64}())
function start!(mind,id,contributors)
    check(!haskey(mind.trials,id),"trial_id_reuse")
    check(!isempty(contributors) && all(x->isfinite(x) && x>0,values(contributors)),"contributors")
    total=sum(values(contributors));check(isfinite(total),"contributor_overflow")
    mind.trials[id]=Trial(forecast_difference_state(),0.,:active,
        Dict(k=>Float64(v/total) for (k,v) in contributors),Dict{String,Any}(),0.,0.)
end
residual(mind)=sum(t.balance["H"] for t in values(mind.trials);init=0.)
function replay(trial,receipt,evidence)
    haskey(trial.receipts,receipt) || return false
    check(trial.receipts[receipt]==evidence,"result_conflict")
    true
end
function mismatch!(mind,id,receipt,expected,observed)
    trial=mind.trials[id];evidence=(:mismatch,expected,observed)
    replay(trial,receipt,evidence) && return false
    check(trial.status==:active,"closed_trial")
    forecast_difference!(trial.balance,expected,observed) || return false
    trial.receipts[receipt]=evidence
    true
end
function resolve!(mind,id,receipt,progress;rules=REWARD_RULES)
    trial=mind.trials[id];evidence=(:resolve,progress,rules)
    replay(trial,receipt,evidence) && return nothing
    check(trial.status==:active,"closed_trial")
    progress===nothing && return nothing
    check(progress isa Real && !(progress isa Bool) && isfinite(progress) &&
        trial.progress<=progress<=1,"progress")
    check(all(x->isfinite(x) && x>=0,values(rules)),"reward_rules")
    delta=Float64(progress)-trial.progress
    # Release only this trial's unresolved difference. Splitting the same
    # evidence into two halves gives the same total reward, absent new debt.
    released=trial.balance["H"]*delta/(1-trial.progress)
    reward=rules.success_base*delta+rules.release_gain*released
    check(isfinite(reward),"reward_overflow")
    forecast_difference!(trial.balance,0.,released)
    for (key,weight) in trial.contributors
        mind.strength[key]=get(mind.strength,key,0.)+weight*reward
    end
    trial.progress=Float64(progress);trial.released+=released;trial.reward+=reward
    trial.status=progress==1 ? :completed : :active
    trial.receipts[receipt]=evidence
    (released=released,reward=reward,H=trial.balance["H"],status=trial.status)
end
function abandon!(mind,id)
    trial=mind.trials[id];check(trial.status==:active,"closed_trial")
    # Retain unresolved history; abandoning is not success or a reward source.
    trial.status=:abandoned
end
end
