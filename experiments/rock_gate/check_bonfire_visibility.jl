using JSON3, Test
include("../../integrations/lightweight_julia/native.jl")
const run="outputs/enclosed-confirm-departure-diagnostic-20261027"
input=JSON3.read(read(joinpath(run,"ordinary/input.json"),String))
objects=prepare_landmark_objects(vcat(collect(input.scene.obstacles),collect(input.scene.visual_landmarks)))
fire=last(objects);@assert fire.light_source==16 && fire.x==0 && fire.z==6
# Suppress emission only; retain exactly the same occluding geometry.
dark=copy(objects);dark[end]=merge(fire,(light_source=0.,))
starts=Dict("npc_a"=>46440,"npc_b"=>39240,"npc_c"=>37380);poses=Any[];rows=Any[]
for line in eachline(joinpath(run,"gate-decisions.jsonl"))
    p=JSON3.read(line);p.stage=="selected" || continue
    starts[p.actor]-60<=p.sec<starts[p.actor]+120 || continue
    push!(poses,(actor=p.actor,sec=p.sec,position=p.position,yaw=p.yaw,method=p.plan.method))
end
for p in poses
    position=Tuple(Float64.(p.position));dx=fire.x-position[1];dz=fire.z-position[2];d=hypot(dx,dz)
    angle=mod(rad2deg(atan(dx,dz))-p.yaw+180,360)-180
    night=mod(p.sec*1_000_000,input.clock.day_us)>=input.clock.phase_boundaries_us[3]
    full=light_fan(objects,position,p.yaw;night=night);without=light_fan(dark,position,p.yaw;night=night)
    visible=length(full)==length(without)+1
    @test length(full)-length(without) in (0,1)
    blockers=Any[]
    for (i,b) in enumerate(objects[1:end-1])
        b.height<1 && continue
        hit=RDLMigrationProbe.ray_hit(position,(dx/d,dz/d),RDLMigrationProbe.Circle(b.x,b.z,b.radius))
        hit!==nothing && hit<max(0.,d-fire.radius) && push!(blockers,(index=i,x=b.x,z=b.z,color=b.color,distance=hit))
    end
    rays=Float64[]
    for a in -90:15:90
        sn,cs=sincosd(p.yaw+a);best=Inf;idx=0
        for (i,o) in enumerate(objects)
            hit=RDLMigrationProbe.ray_hit(position,(sn,cs),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
            if hit!==nothing && hit<=48 && o.height>=1 && hit<best;best=hit;idx=i;end
        end
        idx==length(objects) && push!(rays,a)
    end
    push!(rows,(actor=p.actor,sec=p.sec,position=p.position,yaw=p.yaw,method=p.method,
        angle=angle,distance=d,light_visible=visible,light=visible ? last(full) : nothing,
        shape_rays=rays,in_fov=abs(angle)<=90,blockers=blockers))
end
write("experiments/rock_gate/bonfire_departure_visibility.json",JSON3.write(rows))
println("PASS visibility reconstruction: ",length(rows)," frames")

