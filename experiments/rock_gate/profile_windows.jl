using Profile, JSON3
const run=abspath(ARGS[1]);const out=abspath(ARGS[2]);mkpath(out)
const snapshot=joinpath(run,"source")
const mode=Ref(:warm);const first_sec=Ref(0);const last_sec=Ref(0);const begun=Ref(false);const begin_time=Ref(0.);const duration=Ref(0.)
const start_counts=Ref{Any}();const end_counts=Ref{Any}()
struct WindowDone <: Exception end
function gate_probe!(sec,w,purposes,counts,home)
    if sec==first_sec[] && !begun[]
        start_counts[]=deepcopy(counts);begun[]=true;begin_time[]=time()
        mode[]==:cpu && Profile.start_timer()
        mode[]==:alloc && Profile.Allocs.start(sample_rate=.0001)
    elseif sec==last_sec[]
        mode[]==:cpu && Profile.stop_timer()
        mode[]==:alloc && Profile.Allocs.stop()
        duration[]=time()-begin_time[];end_counts[]=deepcopy(counts)
        throw(WindowDone())
    end
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
# Optional trusted implementations for profiling incremental changes in memory.
foreach(p->include(abspath(p)),ARGS[3:end])
const input=JSON3.read(read(joinpath(run,"ordinary/input.json"),String))
Profile.init(n=10_000_000,delay=.001)
function window(day,kind)
    mode[]=kind;begun[]=false;first_sec[]=day*17280+60;last_sec[]=first_sec[]+512
    try
        run_integrated(input;resume_from=joinpath(run,"ordinary/checkpoints/day-"*lpad(day,3,'0')*".jls"))
        error("window did not stop")
    catch e
        e isa WindowDone || rethrow()
    finally
        Profile.stop_timer();Profile.Allocs.stop()
    end
    Dict(a=>Dict(k=>v-get(start_counts[][a],k,0) for (k,v) in end_counts[][a]) for a in keys(end_counts[]))
end
reports=Any[]
for day in (1,3)
    println("Warm day ",day+1);flush(stdout);window(day,:warm)
    GC.gc();Profile.clear();actions=window(day,:cpu);cpu_seconds=duration[]
    open(joinpath(out,"day$(day+1)-cpu-flat.txt"),"w") do io;Profile.print(io;format=:flat,sortedby=:count);end
    open(joinpath(out,"day$(day+1)-cpu-tree.txt"),"w") do io;Profile.print(io;format=:tree,mincount=5);end
    GC.gc();Profile.Allocs.clear();allocactions=window(day,:alloc);alloc_seconds=duration[]
    @assert actions==allocactions
    stats=Dict{String,Tuple{Int,Int}}()
    data=Profile.Allocs.fetch()
    for x in data.allocs
        frame=findfirst(f->occursin(replace(snapshot,'\\'=>'/'),replace(String(f.file),'\\'=>'/')),x.stacktrace)
        key=frame===nothing ? "outside_snapshot" : let f=x.stacktrace[frame];"$(relpath(String(f.file),snapshot)):$(f.line) $(f.func)" end
        n,b=get(stats,key,(0,0));stats[key]=(n+1,b+x.size)
    end
    ordered=sort(collect(stats);by=x->last(x)[2],rev=true)
    top=[Dict("site"=>k,"samples"=>n,"sampled_bytes"=>b) for (k,(n,b)) in ordered]
    report=Dict("day"=>day+1,"start_second"=>first_sec[]+1,"ticks"=>512,"actors"=>length(actions),"cpu_profile_wall_seconds"=>cpu_seconds,"alloc_profile_wall_seconds"=>alloc_seconds,"sample_rate"=>.0001,"allocation_samples"=>length(data.allocs),"actions"=>actions,"alloc_sites"=>top)
    push!(reports,report);write(joinpath(out,"report.json"),JSON3.write(reports))
    println("Done day ",day+1," CPU ",cpu_seconds," samples ",length(data.allocs));flush(stdout)
end
