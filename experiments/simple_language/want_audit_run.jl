ENV["RDL_LEARNED_TRADE"]="1"
ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_WANT_AUDIT"]="1"
ENV["RDL_COHORT_DAYS"]="18"
# Preserve the pre-fix missing-notice behavior for this historical diagnosis.
ENV["RDL_WANT_WAKE_FROM"]=string(typemax(Int))
include("cohort_run.jl")
