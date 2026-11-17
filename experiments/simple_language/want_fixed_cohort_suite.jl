# Same 20+20 baseline, with notification correction active from the first tick.
ENV["RDL_WANT_WAKE_FROM"]="0"
ENV["RDL_WANT_AUDIT"]="0"
ENV["RDL_ALTERNATE_E"]="0"
ENV["RDL_NO_GESTURES"]="0"
include("want_cohort_suite.jl")
