# CPU kernel benchmark: shared physiology invoked through a parent/leaf MB.
# Excludes world perception, movement and learning; not a whole-LW capacity claim.
using JSON3, Test, Statistics
include("../../src/body/RDLBody.jl")
include("../../src/learning/MemoryBlocks.jl")
using .RDLBody: Body, Digestion, ingest!, digest!, metabolize, RS, MEAL_ENERGY, DIGEST_SECONDS
using .MemoryBlocks

advance(s,::Val{false})=(body=metabolize(s.body,1.),gut=s.gut)
advance(s,::Val{true})=(body=digest!(s.gut,metabolize(s.body,1.),1.),gut=s.gut)
function setup(n,enabled)
    states=[(body=Body(10.,0.,50.,0.),gut=enabled ? Digestion() : nothing) for _ in 1:n]
    if enabled
        for s in states
            ingest!(s.gut,1,50.,0);ingest!(s.gut,2,50.,0)
        end
    end
    mode=Val(enabled)
    leaf=LeafBlock(UInt32(1),s->true,s->1.,s->advance(s,mode))
    block=ParentBlock(100,[ParentBlock(10,[leaf])])
    states,block,[UInt32[] for _ in 1:n]
end
function workload!(states,block,traces,tracking,ticks)
    for _ in 1:ticks, i in eachindex(states)
        result=execute(block,states[i];tracking)
        states[i]=result.output
        traces[i]=result.path
    end
    nothing
end
function measure(n,enabled,tracking,ticks)
    states,block,traces=setup(n,enabled)
    GC.gc()
    m=@timed workload!(states,block,traces,tracking,ticks)
    expected=50.0-ticks*.25*RS+(enabled ? min(2.,ticks/DIGEST_SECONDS)*MEAL_ENERGY : 0.)
    @test all(s->isapprox(s.body.reserve,expected;atol=1e-7),states)
    @test all(p->tracking ? p==UInt32[100,10,1] : isempty(p),traces)
    if enabled
        @test all(s->isapprox(s.gut.eaten*MEAL_ENERGY,s.gut.gut*MEAL_ENERGY+s.gut.absorbed+s.gut.overflow;atol=1e-7),states)
    end
    (seconds=m.time,allocated_bytes=m.bytes,gc_seconds=m.gctime,
        retained_bytes=Base.summarysize((states,traces)),reserve=states[1].body.reserve,
        gut=enabled ? states[1].gut.gut : nothing)
end
ticks=120;repeats=3
conditions=[(digestion=d,tracking=t) for d in (false,true) for t in (false,true)]
for c in conditions
    s,b,t=setup(10,c.digestion);workload!(s,b,t,c.tracking,3)
end
rows=Any[]
@testset "1000/10000 digestion and trace kernels" begin
    for n in (1000,10000)
        samples=Dict((c.digestion,c.tracking)=>Any[] for c in conditions)
        for repeat in 1:repeats, c in (isodd(repeat) ? conditions : reverse(conditions))
            push!(samples[(c.digestion,c.tracking)],measure(n,c.digestion,c.tracking,ticks))
        end
        for d in (false,true)
            @test all(r.reserve==samples[(d,false)][1].reserve && r.gut==samples[(d,false)][1].gut for r in samples[(d,true)])
        end
        for c in conditions
            measured=samples[(c.digestion,c.tracking)]
            row=(agents=n,digestion=c.digestion,tracking=c.tracking,
                median_seconds=median(r.seconds for r in measured),
                median_allocated_bytes=median(r.allocated_bytes for r in measured),
                retained_bytes=measured[1].retained_bytes,samples=measured)
            push!(rows,row);println(JSON3.write(row));flush(stdout)
        end
    end
end
report=(julia=string(VERSION),cpu=Sys.CPU_NAME,threads=Threads.nthreads(),ticks=ticks,repeats=repeats,scope="physiology through hierarchical MB; no world or vision",rows=rows)
write(joinpath(@__DIR__,"results.json"),JSON3.write(report))
