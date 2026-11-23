# Continue the private-warehouse MB communication experiment to total day 60.
ENV["RDL_LEARNED_TRADE"]="1"
ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_ALTERNATE_E"]="0"
ENV["RDL_NO_GESTURES"]="0"
ENV["RDL_COHORT_DAYS"]="50"
include("cohort_run.jl")
