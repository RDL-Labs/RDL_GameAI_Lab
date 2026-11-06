# World adapter: only displacement enters the peripheral sensor. Labels, energy,
# intentions and future movement never enter task_motion_notice.
function wildlife_motion_objects(wildlife_world,wildlife_previous_positions)
    wildlife_world===nothing && return NamedTuple[]
    [(actor="",x=wildlife_world.animals.x[i],z=wildlife_world.animals.z[i],
      vx=i<=length(wildlife_previous_positions) ? wildlife_world.animals.x[i]-wildlife_previous_positions[i][1] : 0.,
      vz=i<=length(wildlife_previous_positions) ? wildlife_world.animals.z[i]-wildlife_previous_positions[i][2] : 0.,
      height=hasproperty(wildlife_world,:life) ? LWGrazing.rabbit_height(wildlife_world,i) : LWGrazing.RABBIT_LIFE.adult_height,
      visibility=hasproperty(wildlife_world,:life) ? LWGrazing.rabbit_visibility(wildlife_world,i) : 1.)
     for i in eachindex(wildlife_world.alive) if wildlife_world.alive[i]]
end

# Deliberate inspection after waking; same forward field, range and occlusion as
# the peripheral sensor, but stationary visible bodies are included. No danger label.
function wildlife_view(position,yaw,objects;occluders=())
    wildlife_observed_features=Any[]
    for wildlife_object in objects
        wildlife_feature=task_motion_notice(position,yaw,(wildlife_object,);occluders,min_speed=0.)
        wildlife_feature===nothing && continue
        delete!(wildlife_feature,"kind")
        wildlife_feature["appearance"]="small_furred_long_eared_body"
        wildlife_feature["moving"]=hypot(wildlife_object.vx,wildlife_object.vz)>=TASK_ATTENTION.motion_speed
        hasproperty(wildlife_object,:height) && (wildlife_feature["height"]=wildlife_object.height)
        push!(wildlife_observed_features,wildlife_feature)
    end
    wildlife_observed_features
end
