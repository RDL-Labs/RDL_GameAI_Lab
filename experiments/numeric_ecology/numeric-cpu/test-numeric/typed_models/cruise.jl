using JSON3, BenchmarkTools, Statistics, Test
include(joinpath(@__DIR__,"../social_loop/models.jl"))
include(joinpath(@__DIR__,"workload.jl"))
plain(x)=JSON3.read(JSON3.write(x),Dict{String,Any})

# Count actual yielded input records outside timing. No instrumentation in models.
mutable struct CountedRecords <: AbstractDict{String,Any}
    data::Records
    visited::Int
end
Base.length(r::CountedRecords)=length(r.data)
Base.getindex(r::CountedRecords,k)=r.data[k]
function Base.iterate(r::CountedRecords,i=1)
    item=iterate(r.data,i)
    item!==nothing && (r.visited+=1)
    item
end

function prepared(n)
    records=Records()
    for i in 1:n
        id=string(i)
        records[id]=D("agent_id"=>"a","target"=>isodd(i) ? "b" : "c",
            "outcome"=>i%7==0 ? "request_not_executed" : i%3==0 ? "given" : "refuse",
            "request_observation_id"=>"request:"*id,"source_observation_id"=>"result:"*id)
    end
    state=pressure_update(nothing,records,"a",3)
    added=deepcopy(records);id=string(n+1)
    added[id]=D("agent_id"=>"a","target"=>"b","outcome"=>"refuse",
        "request_observation_id"=>"request:"*id,"source_observation_id"=>"result:"*id)
    state,records,added
end

report=D("scope"=>"single typed pressure_update; no state/copy policy change",
    "cases"=>D(),"samples_requested"=>30,"evals"=>1,"seconds_limit"=>2,
    "julia_version"=>string(VERSION),"threads"=>Threads.nthreads(),
    "measurement"=>"warm median time, cumulative allocated bytes, not RSS; setup/output/counters excluded")
@testset "Cruise and one-new evidence ownership" begin
    for n in (3,16,64)
        state,records,added=prepared(n);before=plain(state)
        @test before==plain(workload(n)[1])
        result=D()
        for (name,input,new_count) in (("zero_new",records,0),("one_new",added,1))
            input_before=plain(input);counted=CountedRecords(input,0)
            output=pressure_update(state,counted,"a",3)
            @test counted.visited==n+new_count
            @test length(output.parent.records)-length(state.parent.records)==new_count
            @test plain(output)==plain(pressure_update(state,input,"a",3))
            @test output!==state
            @test output.parent.H==state.parent.H+new_count
            @test plain(state)==before
            @test plain(input)==input_before
            if new_count==0
                @test plain(output)==before
            end
            # The unchanged-history result still owns its mutable evidence.
            output.parent.records["1"]["trial"]["source"]["observation_id"]="changed"
            output.methods["b"].H+=100
            @test plain(state)==before
            @test plain(input)==input_before
            result[name]=D("input_records"=>length(input),"records_visited"=>counted.visited,
                "new_parent_records"=>new_count,"new_method_records"=>new_count)
        end
        report["cases"][string(n)]=result
    end
end

for n in (3,16,64)
    state,records,added=prepared(n)
    pressure_update(state,records,"a",3);pressure_update(state,added,"a",3)
    for name in (n==16 ? ("one_new","zero_new") : ("zero_new","one_new"))
        input=name=="zero_new" ? records : added
        trial=@benchmark pressure_update($state,$input,"a",3) samples=30 seconds=2 evals=1
        m=median(trial)
        merge!(report["cases"][string(n)][name],D("median_ns"=>m.time,"allocated_bytes"=>m.memory,
            "allocations"=>m.allocs,"actual_samples"=>length(trial),"times_ns"=>trial.times))
    end
end
open(ARGS[1],"w") do io
    JSON3.write(io,report)
end
println(JSON3.write(report))
