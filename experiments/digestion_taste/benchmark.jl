using JSON3, Test, Statistics
include("../julia_migration/all_loop/loop.jl")
include("../julia_migration/lw_day/food_body.jl")
include("../julia_migration/lw_day/digestion.jl")

function initialize(n,enabled,filled)
    bodies=fill(Body(10.,0.,50.,0.),n)
    guts=enabled ? [Digestion() for _ in 1:n] : nothing
    if enabled && filled
        for g in guts
            ingest!(g,1,50.,0); ingest!(g,2,50.,0)
        end
    end
    bodies,guts
end
function kernel!(bodies,guts,::Val{enabled},ticks) where enabled
    for t in 1:ticks
        for i in eachindex(bodies)
            b=metabolize(bodies[i],1.)
            if enabled; b=digest!(guts[i],b,1.); end
            bodies[i]=b
        end
    end
    nothing
end
function measure(n,enabled,filled,ticks)
    bodies,guts=initialize(n,enabled,filled)
    state_bytes=Base.summarysize((bodies,guts))
    GC.gc()
    m=@timed kernel!(bodies,guts,Val(enabled),ticks)
    # Check results outside the timed section; retain observable final state.
    expected=50.0-ticks*.25*RS+(enabled && filled ? min(2.,ticks/DIGEST_SECONDS)*MEAL_ENERGY : 0.)
    @test all(b->isapprox(b.reserve,expected;atol=1e-7),bodies)
    if enabled
        @test all(g->isapprox(g.eaten*MEAL_ENERGY,g.gut*MEAL_ENERGY+g.absorbed+g.overflow;atol=1e-7),guts)
    end
    (seconds=m.time,allocated_bytes=m.bytes,gc_seconds=m.gctime,state_bytes=state_bytes,
        final_reserve=bodies[1].reserve,final_gut=enabled ? guts[1].gut : nothing)
end

ticks=3600; repetitions=5
for enabled in (false,true), filled in (false,true)
    b,g=initialize(10,enabled,filled); kernel!(b,g,Val(enabled),10)
end
rows=Any[]
@testset "measured body updates and nutrient conservation" begin
    for n in (1000,10000), filled in (false,true)
        off=Any[]; on=Any[]
        for repeat in 1:repetitions
            for enabled in (isodd(repeat) ? (false,true) : (true,false))
                push!(enabled ? on : off,measure(n,enabled,filled,ticks))
            end
        end
        offmedian=median(r.seconds for r in off); onmedian=median(r.seconds for r in on)
        row=(agents=n,filled=filled,ticks=ticks,repetitions=repetitions,
            off_median_seconds=offmedian,on_median_seconds=onmedian,
            ratio=onmedian/offmedian,extra_ms_per_sim_second=1000*(onmedian-offmedian)/ticks,
            off=off,on=on)
        push!(rows,row)
        println(JSON3.write((agents=n,filled=filled,off=offmedian,on=onmedian,ratio=row.ratio,
            extra_ms_per_tick=row.extra_ms_per_sim_second,on_allocated_bytes=on[1].allocated_bytes,
            off_state_bytes=off[1].state_bytes,on_state_bytes=on[1].state_bytes)))
        flush(stdout)
    end
end
report=(julia=string(VERSION),threads=Threads.nthreads(),cpu=Sys.CPU_NAME,
    ticks=ticks,repetitions=repetitions,peak_process_rss_bytes=Sys.maxrss(),rows=rows)
output=isempty(ARGS) ? joinpath(@__DIR__,"benchmark-results.json") : abspath(only(ARGS))
mkpath(dirname(output))
write(output,JSON3.write(report))
