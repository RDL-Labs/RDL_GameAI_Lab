# Sequential isolated Julia processes: same day13 input as the previous cohort.
using JSON3
length(ARGS)==2 || error("usage: learned_cohort_suite.jl BASE OUTPUT_ROOT")
base,output=abspath.(ARGS)
ispath(output) && error("fresh output required")
mkpath(output)
ENV["RDL_LEARNED_TRADE"]="1"
runner=joinpath(@__DIR__,"cohort_run.jl")
project=normpath(joinpath(@__DIR__,"../.."))
continued=joinpath(output,"continue20");trained=joinpath(output,"training");mixed=joinpath(output,"mixed20")
for arguments in (["continue",base,continued],["train",base,trained],["join",continued,mixed,trained])
 println("START ",join(arguments," "));flush(stdout)
 run(`$(Base.julia_cmd()) --startup-file=no --project=$project $runner $arguments`)
end
write(joinpath(output,"completed.json"),JSON3.write((days=53,stages=[continued,trained,mixed])))
