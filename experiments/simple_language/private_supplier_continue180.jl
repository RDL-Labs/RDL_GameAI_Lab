# Continue the day-60 private-warehouse experiment for 120 more days (total 180).
ENV["RDL_LEARNED_TRADE"]="1"
ENV["RDL_WANT_VOICE"]="1"
ENV["RDL_ALTERNATE_E"]="0"
ENV["RDL_NO_GESTURES"]="0"
ENV["RDL_COHORT_DAYS"]="120"
include("cohort_run.jl")
