function observe_prey(w,p,a,alive,t)
    observations=NamedTuple{(:id,:x,:z,:distance),Tuple{Int,Float64,Float64,Float64}}[]
    for i in eachindex(alive)
        alive[i] && visible(w,p,a,i,t) || continue
        push!(observations,(id=i,x=a.x[i],z=a.z[i],distance=hypot(a.x[i]-p.x,a.z[i]-p.z)))
    end
    observations
end
