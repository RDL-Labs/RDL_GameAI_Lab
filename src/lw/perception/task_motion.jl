include("../../perception/load.jl")
include("../parameters.jl")
# Peripheral motion sensor. This reports motion, not danger or an
# action command. Shared by focused work and the isolated sensor experiment.
# Range/speed are provisional sensory constants, shared across actors.
function task_motion_notice(position,yaw,objects;occluders=(),range=TASK_ATTENTION.motion_range,min_speed=TASK_ATTENTION.motion_speed,illumination=1.)
    s,c=sincos(deg2rad(yaw))
    nearest=nothing;nearest_distance=Inf
    for o in objects
        dx,dz=o.x-position[1],o.z-position[2]
        distance=hypot(dx,dz)
        # Optional apparent-size/vegetation factor from the world sensor adapter.
        # Existing human/object inputs default to the unchanged full range.
        distance<=range*AmbientVision.range_factor(:human,illumination)*get(o,:visibility,1.) && dx*s+dz*c>=0 || continue
        distance<nearest_distance || continue
        hypot(o.vx,o.vz)>=min_speed || continue
        any(wall->segment_hit(position,(o.x,o.z),wall,0.),occluders) && continue
        # No identity, food inventory, threat label, or unseen world state leaks.
        nearest_distance=distance
        nearest=D("kind"=>"motion","forward"=>dx*s+dz*c,"right"=>dx*c-dz*s,
            "distance"=>distance)
    end
    nearest
end
