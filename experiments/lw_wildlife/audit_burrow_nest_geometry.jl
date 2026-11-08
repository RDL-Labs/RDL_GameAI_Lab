using Serialization,JSON3
root=ARGS[1];include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
for day in (64,65,69)
 s=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls")).world
 for mom in (12,117,304)
  kids=[i for i in eachindex(s.alive) if s.life.mother[i]==mom && s.life.born[i]>360*17280]
  isempty(kids)&&continue
  kid=first(kids);nest=s.life.nest[kid];k=H.cell(s.world,nest...);center=H.center(s.world,k)
  println(JSON3.write((day,mom,position=(s.animals.x[mom],s.animals.z[mom]),nest,center,nest_center_distance=hypot(nest[1]-center[1],nest[2]-center[2]),energy=s.animals.energy[mom],target=s.animals.target[mom],state=H.STATES[s.animals.state[mom]],blocked=s.animals.blocked[mom],cellsize=s.world.cellsize)))
 end
end
