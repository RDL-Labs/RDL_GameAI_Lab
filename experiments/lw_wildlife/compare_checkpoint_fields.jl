using Serialization,Test
include(joinpath(ARGS[1],"source/experiments/lw_wildlife/predator_generations.jl"))
a=deserialize(ARGS[2]);b=deserialize(ARGS[3]);differences=String[];seen=Set{Tuple{UInt,UInt}}()
function compare(a,b,path)
 isequal(a,b) && return
 typeof(a)==typeof(b) || (push!(differences,path*": type");return)
 pair=(objectid(a),objectid(b));pair in seen && return;push!(seen,pair)
 if a isa AbstractDict
  Set(keys(a))==Set(keys(b)) || (push!(differences,path*": keys");return)
  for k in keys(a);compare(a[k],b[k],path*"/"*string(k));end
 elseif a isa AbstractArray
  size(a)==size(b) || (push!(differences,path*": size");return)
  for i in eachindex(a);compare(a[i],b[i],path*"/"*string(i));end
 elseif fieldcount(typeof(a))>0
  for f in fieldnames(typeof(a));compare(getfield(a,f),getfield(b,f),path*"/"*string(f));end
 else
  push!(differences,path*": "*repr(a)*" != "*repr(b))
 end
end
compare(a,b,"checkpoint");foreach(println,differences);@test isempty(differences)
println("SEMANTIC_CHECKPOINT_MATCH")
