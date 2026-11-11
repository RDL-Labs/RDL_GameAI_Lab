using Serialization, JSON3
const audit_root=abspath(ARGS[1])
include(joinpath(audit_root,"source/src/lw/LW.jl"))
const audit_counts=Dict{String,Int}()
function audit_sort!(queue;by,stage)
    audit_counts[stage*"_calls"]=get(audit_counts,stage*"_calls",0)+1
    audit_counts[stage*"_items"]=get(audit_counts,stage*"_items",0)+length(queue)
    issorted(queue;by=by) && (audit_counts[stage*"_already_sorted"]=get(audit_counts,stage*"_already_sorted",0)+1)
    sort!(queue;by=by)
end
audit_source=read(joinpath(audit_root,"source/src/lw/learning/mb_return_outlook.jl"),String)
audit_source=first(split(audit_source,"function mb_return_estimate"))
audit_source=replace(audit_source,"function mb_return_outlook!("=>"function mb_return_outlook_audit!(")
audit_sort_text="sort!(queue,by=x->(x.cost,x.node,x.path_key))"
@assert count(audit_sort_text,audit_source)==2
audit_source=replace(audit_source,audit_sort_text=>"Main.audit_sort!(queue,by=x->(x.cost,x.node,x.path_key),stage=\"head\")";count=1)
audit_source=replace(audit_source,audit_sort_text=>"Main.audit_sort!(queue,by=x->(x.cost,x.node,x.path_key),stage=\"tail\")")
Base.include_string(LW,audit_source)
audit_rows=Any[]
for checkpoint_day in (38,40)
    checkpoint=deserialize(joinpath(audit_root,"run/checkpoints/day-"*lpad(checkpoint_day,3,'0')*".jls"))
    for actor in sort(collect(keys(checkpoint.state[:mb_maps])))
        original=deepcopy(checkpoint.state[:mb_maps][actor])
        haskey(original,"return_outlook") && (original["return_outlook"]["next_us"]=0)
        instrumented=deepcopy(original)
        now=checkpoint_day*17_280_000_000
        baseline=LW.mb_return_outlook!(original,now)
        empty!(audit_counts)
        observed=LW.mb_return_outlook_audit!(instrumented,now)
        @assert baseline==observed
        push!(audit_rows,(checkpoint_day,actor,nodes=length(original["nodes"]),edges=length(original["edges"]),counts=copy(audit_counts),equal=true))
    end
end
audit_result=(scope="One forced return-outlook rebuild per actor from day38/day40 saved memory; not full-day frequencies or a speed benchmark.",rows=audit_rows)
write(ARGS[2],JSON3.write(audit_result))
println(JSON3.write(audit_result))
