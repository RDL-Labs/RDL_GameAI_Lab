using BenchmarkTools, Statistics, JSON3, Test
include("../../src/body/macronutrients.jl")
using .Macronutrients
include("../../src/lw/configured_paths/body_local_cycle.jl")

# Isolated experiment: no change to the currently selected body demand rule.
# All curves use equal weights, as requested; precompute fixed exponential divisor.
const DEMAND_EXP_K=3.0
const DEMAND_EXP_NORMALIZER=inv(expm1(DEMAND_EXP_K))
@inline demand_curve(x,::Val{:linear})=x
@inline demand_curve(x,::Val{:square})=x*x
@inline demand_curve(x,::Val{:cubic})=x*x*x
@inline demand_curve(x,::Val{:exponential})=expm1(DEMAND_EXP_K*x)*DEMAND_EXP_NORMALIZER

# Three nutrients per evaluation. Runtime array input and consumed checksum avoid
# constant folding/dead-code elimination; no @fastmath or explicit SIMD promises.
function curve_batch(inputs,curve::C) where C
    checksum=0.0
    for (sugar,fat,protein) in inputs
        checksum+=(demand_curve(sugar,curve)+demand_curve(fat,curve)+demand_curve(protein,curve))/3
    end
    checksum
end

# The same raw deficit calculations as body_signals; only curve and equal weights
# differ. Cost includes fullness and mobility, not just exp/multiply instructions.
@inline function measured_signals(b,p,curve::C) where C
    sugar=clamp(1-b.sugar/p.sugar_reference,0.0,1.0)
    fat=clamp(1-b.fat/p.fat_reference,0.0,1.0)
    tissue=clamp((p.tissue_target-b.tissue)/(p.tissue_target-p.tissue_minimum),0.0,1.0)
    protein=max(tissue,clamp(1-b.amino/p.amino_reference,0.0,1.0))
    fullness=clamp(sum(b.gut)/p.gut_capacity,0.0,1.0)
    demand=clamp((demand_curve(sugar,curve)+demand_curve(fat,curve)+demand_curve(protein,curve))/3-
                  p.gut_satiety_weight*fullness,0.0,1.0)
    ability=clamp((b.tissue-p.tissue_minimum)/(p.tissue_target-p.tissue_minimum),0.0,1.0)
    (;demand,sugar,fat,protein,fullness,ability)
end

function body_ten_days(curve::C,::Val{record};dt=CONFIGURED_BODY_CYCLE.step_hours) where {C,record}
    b=MacroBody(); p=MacroParameters(); cycle=CONFIGURED_BODY_CYCLE
    checksum=0.0
    # No dictionaries/strings per record; this is not the full LW or original
    # JSON/CSV/report pipeline. Both variants run the actual advance! kernel.
    log=record ? Vector{NTuple{6,Float64}}(undef,10*round(Int,24/dt)) : nothing
    index=0
    for day in 1:10, step in 0:round(Int,24/dt)-1
        hour=step*dt
        phase=configured_body_phase(hour)
        if step==round(Int,cycle.return_end/dt)
            feed!(b,ntuple(i->cycle.meal_energy*cycle.meal_shares[i],3),p)
        end
        signals=measured_signals(b,p,curve)
        checksum+=signals.demand
        index+=1
        record && (log[index]=(b.sugar,b.fat,b.tissue,b.amino,signals.demand,signals.fullness))
        advance!(b,p,dt;intensity=phase.intensity,sleeping=phase.sleeping)
    end
    (;checksum,log,final=body_snapshot(b,p))
end

function benchmark_main()
    length(ARGS)==1 || error("usage: benchmark_demand.jl NEW_RESULT_JSON")
    ispath(ARGS[1]) && error("output exists")
    # Wide deterministic runtime inputs, including endpoints and asymmetric needs.
    inputs=[(i/4095,mod(i*31,4096)/4095,mod(i*97,4096)/4095) for i in 0:4095]
    names=[:linear,:square,:cubic,:exponential]
    @testset "demand benchmark validity" begin
        base=body_ten_days(Val(:linear),Val(false))
        p=MacroParameters(body_demand_squared=false,body_demand_sugar_weight=1/3,body_demand_fat_weight=1/3,body_demand_tissue_weight=1/3)
        for name in names
            curve=Val(name)
            @test demand_curve(0.0,curve)==0.0
            @test demand_curve(1.0,curve)≈1.0
            @test issorted([demand_curve(x,curve) for x in 0:0.01:1])
            without=body_ten_days(curve,Val(false))
            withlog=body_ten_days(curve,Val(true))
            @test without.final==base.final # physiological trajectory must not change
            @test without.checksum==withlog.checksum
            @test length(withlog.log)==2880
            @test isfinite(curve_batch(inputs,curve))
        end
        for (s,f,a) in inputs[1:127:end]
            b=MacroBody(sugar=30s,fat=200f,amino=6a)
            @test measured_signals(b,p,Val(:linear)).demand≈body_signals(b,p).body_demand
        end
    end
    # Warm every specialization before timing. 3 serial passes, reversed middle.
    for name in names
        curve_batch(inputs,Val(name));body_ten_days(Val(name),Val(false));body_ten_days(Val(name),Val(true))
    end
    rows=NamedTuple[]
    for pass in 1:3
        for name in (pass==2 ? reverse(names) : names)
            curve=Val(name)
            for scope in (:curve_batch,:body,:body_with_log)
                trial=if scope==:curve_batch
                    @benchmark curve_batch($inputs,$curve) samples=300 seconds=0.3 evals=1
                elseif scope==:body
                    @benchmark body_ten_days($curve,Val(false)) samples=300 seconds=0.3 evals=1
                else
                    @benchmark body_ten_days($curve,Val(true)) samples=300 seconds=0.3 evals=1
                end
                push!(rows,(;pass,curve=string(name),scope=string(scope),samples=length(trial),
                    median_ns=median(trial).time,p25_ns=quantile(trial.times,.25),p75_ns=quantile(trial.times,.75),
                    memory=median(trial).memory,allocs=median(trial).allocs,gc_ns=median(trial).gctime))
            end
        end
    end
    aggregate=NamedTuple[]
    for scope in ("curve_batch","body","body_with_log"), name in names
        selected=filter(r->r.curve==string(name) && r.scope==scope,rows)
        times=[r.median_ns for r in selected]
        push!(aggregate,(;scope,curve=string(name),median_ns=median(times),
            pass_min_ns=minimum(times),pass_max_ns=maximum(times),
            memory=maximum(r.memory for r in selected),allocs=maximum(r.allocs for r in selected)))
    end
    report=(;julia=string(VERSION),cpu=Sys.CPU_NAME,cpu_threads=Sys.CPU_THREADS,
        julia_threads=Threads.nthreads(),batch_nutrients=3,batch_evaluations=length(inputs),
        body_days=10,body_updates=2880,exponential_k=DEMAND_EXP_K,weights=(1/3,1/3,1/3),
        notes="Serial warm benchmarks, reversed second pass, no file I/O/compile/full LW. Results consumed. Curve changes demand, not metabolism.",
        rows,aggregate)
    write(ARGS[1],JSON3.write(report))
    println(JSON3.write(aggregate))
end
benchmark_main()
