include(joinpath(@__DIR__,"run.jl"))
include(joinpath(@__DIR__,"checks.jl"))
for dir in ARGS
    validate_integrated(JSON3.read(read(joinpath(dir,"result.json"),String)),
        JSON3.read(read(joinpath(dir,"spec.json"),String)))
end
