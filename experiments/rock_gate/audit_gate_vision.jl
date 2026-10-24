using JSON3
root=normpath(joinpath(@__DIR__,"../.."));run=abspath(ARGS[1])
include(joinpath(run,"source/integrations/lightweight_julia/native.jl"))
function audit_gate_vision(run)
input=JSON3.read(read(joinpath(run,"narrow/input.json"),String));scene=input.scene
Row=NamedTuple{(:sec,:actor,:position,:reserve,:return_active),Tuple{Int,String,Vector{Float64},Float64,Bool}}
positions=JSON3.read(read(joinpath(run,"narrow/positions.json"),String),Vector{Row})
println("Loaded $(length(positions)) trace rows");flush(stdout)
objects=prepare_landmark_objects(scene.obstacles);home=scene.home
stats=Dict(a=>D("observations_reconstructed"=>0,"gap_ray_frames"=>0,"gap_bracketed_frames"=>0,
    "orange_frames"=>0,"examples"=>Any[]) for a in IDS)
prev=Dict(a=>Tuple(Float64.(scene.positions[i])) for (i,a) in enumerate(IDS))
function exit_distance(p,sn,cs)
 x,z=p[1]-home[1],p[2]-home[2];b=x*sn+z*cs
 disc=b*b+25-x*x-z*z
 disc>=0 ? -b+sqrt(disc) : Inf
end
for (row_index,row) in enumerate(positions)
 mod(row_index,30000)==0 && (println("VISION $row_index / $(length(positions))");flush(stdout))
 a=String(row.actor);p=prev[a];q=Tuple(Float64.(row.position));prev[a]=q
 dx,dz=q[1]-p[1],q[2]-p[2]
 # Moving fixes actual heading; the next tick's sensors use that heading.
 hypot(dx,dz)>1e-8 && row.sec<3*17280 || continue
 yaw=rad2deg(atan(dx,dz));ob=lateral_obstacles(scene.obstacles,q,yaw,"audit")
 fan=landmark_fan(objects,q,yaw,"audit")
 visible=Int[]
 for (i,sample) in enumerate(ob["samples"])
  sn,cs=sincosd(yaw+sample["angle"]);t=exit_distance(q,sn,cs)
  if 0<t<12 && q[2]+cs*t<home[2] && sample["distance"]>t+1e-6
   push!(visible,i)
  end
 end
 bracketed=any(i->1<i<7 && ob["samples"][i]["status"]=="clear" &&
     ob["samples"][i-1]["status"]=="hit" && ob["samples"][i+1]["status"]=="hit",visible)
 orange=any(f->f["color"]=="orange",fan["features"])
 s=stats[a];s["observations_reconstructed"]+=1;s["gap_ray_frames"]+=Int(!isempty(visible))
 s["gap_bracketed_frames"]+=Int(bracketed);s["orange_frames"]+=Int(orange)
 if !isempty(visible) && length(s["examples"])<4
  push!(s["examples"],D("observation_sec"=>row.sec,"position"=>q,"yaw"=>yaw,
    "relative_ray_angles"=>[ob["samples"][i]["angle"] for i in visible],"bracketed"=>bracketed,"orange"=>orange))
 end
end
r=JSON3.read(read(joinpath(run,"narrow/run/result.json"),String))
for a in IDS
 stats[a]["orange_method_events"]=count(e->e.actor==a && e.method=="landmark:orange",r.events)
end
write(joinpath(run,"gate-vision-audit.json"),JSON3.write(stats));println(JSON3.write(stats))
end
audit_gate_vision(run)
