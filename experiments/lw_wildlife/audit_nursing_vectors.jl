using JSON3,Serialization
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
records=JSON3.read(read(ARGS[2],String));out=Any[]
for r in records
 s=deserialize(joinpath(root,"checkpoints/day-"*lpad(r.day-1,3,'0')*".jls")).world
 for sample in (r.samples[min(2,length(r.samples))],)
  m=r.m;a=s.animals;w=s.world;p=Tuple(sample.position);goal=Tuple(sample.nest)
  a.x[m],a.z[m]=p;a.heading[m]=atan(goal[2]-p[2],goal[1]-p[1]);s.overrides[m]=H.SEARCH
  raw=a.heading[m];potential=G.configured_rabbit_potential(w,a,m,.2,s.overrides);boundary=H.configured_boundary_heading(w,p,potential)
  variants=[(name=name,heading=h,clear=H.clear(w,p,(p[1]+.2cos(h),p[2]+.2sin(h))),next_distance=hypot(p[1]+.2cos(h)-goal[1],p[2]+.2sin(h)-goal[2])) for (name,h) in (("direct",raw),("obstacle_potential",potential),("boundary_added",boundary))]
  push!(out,(mother=m,position=p,goal,extent=(w.xmin,w.xmax,w.zmin,w.zmax),distance=hypot(p[1]-goal[1],p[2]-goal[2]),variants))
 end
end
println(JSON3.write(out));write(ARGS[3],JSON3.write(out))
