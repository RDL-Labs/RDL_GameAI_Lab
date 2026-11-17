ENV["RDL_LEARNED_TRADE"]="1"
ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_WANT_AUDIT"]="1"
ENV["RDL_COHORT_DAYS"]="9"
# Preserve original actions through the offer, enable correction next tick.
ENV["RDL_WANT_WAKE_FROM"]="362943000000"
include("cohort_run.jl")
