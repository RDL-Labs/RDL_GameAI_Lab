# Experimental only: production keeps full queue sorting until a repeatable
# whole-day benefit is established. Never modify the frozen source directory.
function queue_merge_overlay(source_directory,destination)
    mkpath(destination)
    for (name,anchor,old,new) in (
        ("mb_map.jl","        for key in Iterators.take(edges,8)",
         "sort!(queue,by=x->(x.cost,x.path_key));length(queue)>64 && resize!(queue,64)",
         "mb_queue_merge!(queue,queue_prefix_length,64,x->(x.cost,x.path_key))"),
        ("mb_return_outlook.jl","        for key in get(incoming,item.node,String[])",
         "sort!(queue,by=x->(x.cost,x.node,x.path_key));length(queue)>256 && resize!(queue,256)",
         "mb_queue_merge!(queue,queue_prefix_length,256,x->(x.cost,x.node,x.path_key))"))
        source=read(joinpath(source_directory,name),String)
        @assert count(anchor,source)==1
        @assert count(old,source)==1
        source=replace(source,anchor=>"        queue_prefix_length=length(queue)\n"*anchor,old=>new)
        name=="mb_map.jl" && (source="include(\"mb_queue.jl\")\n"*source)
        write(joinpath(destination,name),source)
    end
    cp(joinpath(@__DIR__,"mb_queue_candidate.jl"),joinpath(destination,"mb_queue.jl"))
    destination
end
