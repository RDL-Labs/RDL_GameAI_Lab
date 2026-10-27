# Test-only restriction, applied to the isolated source snapshot, never production files.
function restrict_retrieval_source(source,k)
    k in (1,2,4,8) || error("retrieval top-k must be 1, 2, 4 or 8")
    budget="batch=8+4floor(Int,clamp(Float64(H),0.,32.))"
    fallback="best_weight>=.25 && break"
    @assert count(budget,source)==1
    @assert count(fallback,source)==1
    replace(source,budget=>"batch=$k",fallback=>"break # Experimental strict top-k: no H/weak-fit expansion.")
end
