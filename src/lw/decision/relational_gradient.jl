# Common finite transition field. Domain adapters supply owner-observed utility
# before/after, outcome probability and cost. No coordinates/assets are read here.
function relational_transition(before,after;probability=1.,cost=0.)
    all(isfinite,(before,after,probability,cost)) || error("nonfinite relational field")
    0<=probability<=1 && cost>=0 || error("invalid relational field")
    delta=Float64(after-before-cost)
    (delta=delta,expected=Float64(probability)*delta,probability=Float64(probability),cost=Float64(cost))
end

"Refine one relation among feasible local changes; stable ties preserve its heading/terms."
function relational_best(evaluate,candidates;tolerance=1e-12)
    best=nothing
    for candidate in candidates
        field=evaluate(candidate);field===nothing && continue
        if best===nothing || field.expected>best.field.expected+tolerance
            best=(candidate=candidate,field=field)
        end
    end
    best
end
