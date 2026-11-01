using Profile, Serialization, JSON3
length(ARGS)==1 || error("usage: summarize_cpu_day.jl PROFILE_OUTPUT")
root=ARGS[1];data,lookup=deserialize(joinpath(root,"cpu-profile.jls"))
function summarize(data,lookup)
    inclusive=Dict{String,Int}();nearest=Dict{String,Int}();samples=0;start=1
    for stop in eachindex(data)
        Profile.is_block_end(data,stop) || continue
        # Julia 1.13 metadata: four fields followed by two null separators.
        if data[stop-5]==1
            samples+=1;seen=Set{String}();leaf=nothing
            for k in start:stop-6
                frames=get(lookup,data[k],nothing);frames===nothing && continue
                for frame in (frames isa Vector ? frames : (frames,))
                    frame.from_c && continue
                    path=replace(string(frame.file),'\\'=>'/')
                    occursin("/src/",path) && occursin("RDL_GameAI_Lab",path) || continue
                    short=split(path,"/src/")[end]
                    key=short*":"*string(frame.func)
                    push!(seen,key)
                    leaf===nothing && (leaf=key)
                end
            end
            for key in seen;inclusive[key]=get(inclusive,key,0)+1;end
            key=leaf===nothing ? "outside_project" : leaf
            nearest[key]=get(nearest,key,0)+1
        end
        start=stop+1
    end
    rows(d)=[(function_key=k,samples=v,percent=100v/max(1,samples)) for (k,v) in sort(collect(d);by=x->(-last(x),first(x)))]
    (samples=samples,inclusive=rows(inclusive),nearest_project_frame=rows(nearest),
     note="Inclusive shares overlap; nearest project frame charges library/runtime callees to the innermost project frame. Sampling estimates, not exact timers. Main thread only.")
end
result=summarize(data,lookup)
write(joinpath(root,"cpu-summary.json"),JSON3.write(result))
for row in Iterators.take(result.inclusive,35);println(round(row.percent;digits=2),"% ",row.function_key);end
