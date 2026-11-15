# Optional observed communication evidence. No token meanings or speaker intent
# live here. Domain observation/learning supplies counts of visible outcomes.
# Two equivalent observations retain the pre-existing prediction as a weak prior.
# Count units, provisional initial calibration; absent evidence leaves it exact.
const TRADE_COMMUNICATION_RULES=(prior_samples=2.,)
function trade_communication_prediction(prior,evidence,partner,offer_id,now)
    evidence===nothing && return nothing
    get(evidence,"partner",nothing)==partner || return nothing
    get(evidence,"offer_id",nothing)==offer_id || return nothing
    get(evidence,"observed_us",typemax(Int))<=now<get(evidence,"expires_us",typemin(Int)) || return nothing
    successes=get(evidence,"successes",0.);failures=get(evidence,"failures",0.)
    all(x->x isa Real && isfinite(x) && x>=0,(successes,failures)) || error("invalid communication evidence")
    successes+failures>0 || return nothing
    prior_samples=TRADE_COMMUNICATION_RULES.prior_samples
    probability=(prior_samples*prior+successes)/(prior_samples+successes+failures)
    D("prior"=>prior,"probability"=>probability,"successes"=>successes,"failures"=>failures,
      "tokens"=>copy(get(evidence,"tokens",String[])),"context"=>get(evidence,"context",nothing),
      "evidence_ids"=>copy(get(evidence,"evidence_ids",String[])),"observation_id"=>get(evidence,"observation_id",nothing))
end
