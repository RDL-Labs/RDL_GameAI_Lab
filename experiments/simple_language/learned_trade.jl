# Local adapter: binds a currently observed expression to one peer/transaction.
# No food referent is guessed from co-occurrence; observed trade terms stay intact.
function learned_trade_evidence(memory,observation,context,partner,offer_id,observed_us,expires_us)
    observation===nothing && return nothing
    tokens=Set(String.(split(observation.text)))
    observation.motion===nothing || push!(tokens,"gesture:"*observation.motion)
    isempty(tokens) && return nothing
    successes=0;failures=0;ids=String[]
    # Union by observation ID: simultaneous word+gesture must not count the same
    # experience twice. Only previous episodes; current ID cannot explain itself.
    for id in sort(collect(keys(memory.receipts)))
        id==observation.id && continue
        previous,before,after=memory.receipts[id]
        before==context || continue
        previous_tokens=Set(String.(split(previous.text)))
        previous.motion===nothing || push!(previous_tokens,"gesture:"*previous.motion)
        isempty(intersect(tokens,previous_tokens)) && continue
        after in ("object-transferred","object-withdrawn") || continue
        successes+=after=="object-transferred";failures+=after=="object-withdrawn"
        push!(ids,id)
    end
    successes+failures==0 && return nothing
    Dict{String,Any}("partner"=>partner,"offer_id"=>offer_id,"observed_us"=>observed_us,"expires_us"=>expires_us,
        "successes"=>successes,"failures"=>failures,"tokens"=>sort(collect(tokens)),
        "evidence_ids"=>ids,"context"=>context,"observation_id"=>observation.id)
end
