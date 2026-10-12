using JSON3, BenchmarkTools, InteractiveUtils
include("../src/RDLMigrationProbe.jl")
using .RDLMigrationProbe

function main()
    root = normpath(joinpath(@__DIR__,"../../fixtures"))
    parse_result = @timed [JSON3.read(s) for s in eachline(joinpath(root,"geometry_inputs.jsonl"))]
    convert_result = @timed prepare.(parse_result.value)
    queries = convert_result.value
    first_result = @timed batch(queries)
    if length(ARGS)>0 && ARGS[1]=="cold"
        println(JSON3.write(Dict("valid"=>length(first_result.value)==length(queries),"julia"=>string(VERSION))))
        return
    end
    measurements = Any[]
    for n in (23,1024)
        qs=queries[1:n]
        trial=@benchmark batch($qs) seconds=1 samples=200 evals=1
        push!(measurements,Dict("n"=>n,"times_ns"=>trial.times,"gc_times_ns"=>trial.gctimes,
            "allocated_bytes"=>trial.memory,"allocations"=>trial.allocs))
    end
    open(ARGS[1]*".warntype.txt","w") do io
        code_warntype(io,batch,(typeof(queries),))
    end
    write(ARGS[1],JSON3.write(Dict("julia"=>string(VERSION),"threads"=>Threads.nthreads(),
        "parse_seconds"=>parse_result.time,"conversion_seconds"=>convert_result.time,
        "first_batch_seconds"=>first_result.time,"first_batch_gc_seconds"=>first_result.gctime,
        "first_batch_allocated_bytes"=>first_result.bytes,"measurements"=>measurements)))
end
main()
