using JSON3, BenchmarkTools, Statistics, Test
module Baseline end
module Typed end
Base.include(Baseline,abspath(ARGS[1]))
Base.include(Typed,joinpath(@__DIR__,"../social_loop/models.jl"))
for m in (Baseline,Typed)
    Base.include(m,joinpath(@__DIR__,"workload.jl"))
end
plain(x)=JSON3.read(JSON3.write(x),Dict{String,Any})
wrap(x)=Dict("value"=>x)

@testset "Typed model ownership and parity" begin
    for n in (3,16,64)
        @test plain(wrap(Baseline.workload(n,true)))==plain(wrap(Typed.workload(n,true)))
    end
    initial=Typed.ginitial("a")
    @test initial isa Typed.GoalState
    source=Typed.D("observation_id"=>"one","nested"=>[1,2])
    active=Typed.gbegin(initial,"one",source)
    source["nested"][1]=99
    @test active.trial["source"]["nested"]==[1,2]
    @test initial.trial===nothing
    before=plain(active)
    done=Typed.gfinish(active,"one",false,true,"result")
    @test plain(active)==before
    snapshot=deepcopy(done)
    next=Typed.gfinish(Typed.gbegin(done,"two",Typed.D()),"two",true,true,"result2")
    next.records["one"]["trial"]["source"]["nested"][1]=88
    @test plain(done)==plain(snapshot)
    @test done.H==1 && next.H==0
    p,_,_=Typed.workload(3)
    @test p isa Typed.AidPressure
    @test eltype(values(p.methods))==Typed.GoalState
    before=plain(p);copy_p=deepcopy(p)
    copy_p.parent.records["1"]["trial"]["source"]["observation_id"]="changed"
    copy_p.methods["b"].H+=1
    @test plain(p)==before
end

report=Dict{String,Any}("scope"=>"goal and aid state only; not full A2/LW speed", "cases"=>Dict(),
    "samples"=>15,"seconds_limit"=>2,"evals"=>1,"compilation"=>"excluded by warmup",
    "measurement"=>"BenchmarkTools median time and allocated bytes; not peak RSS")
for n in (3,16,64)
    result=Dict{String,Any}()
    # Alternate order across sizes; both methods are explicitly warmed first.
    Baseline.workload(n);Typed.workload(n)
    for name in (n==16 ? ("typed","baseline") : ("baseline","typed"))
        f=name=="typed" ? Typed.workload : Baseline.workload
        trial=@benchmark $f($n) samples=15 seconds=2 evals=1
        m=median(trial)
        result[name]=Dict("median_ns"=>m.time,"allocated_bytes"=>m.memory,"allocations"=>m.allocs,
            "samples"=>length(trial),"times_ns"=>trial.times)
    end
    result["time_ratio_baseline_over_typed"]=result["baseline"]["median_ns"]/result["typed"]["median_ns"]
    result["allocation_ratio_baseline_over_typed"]=result["baseline"]["allocated_bytes"]/result["typed"]["allocated_bytes"]
    report["cases"][string(n)]=result
end
open(ARGS[2],"w") do io
    JSON3.write(io,report)
end
println(JSON3.write(report))
