using Serialization,JSON3
root=ARGS[1]
include(joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
function export_grass()
 frames=Any[];geometry=nothing
 for day in 0:90
  saved=deserialize(joinpath(root,"checkpoints/day-"*lpad(day,3,'0')*".jls"))
  s=saved.world;w=s.world
  geometry===nothing && (geometry=(xmin=w.xmin,zmin=w.zmin,nx=w.nx,nz=w.nz,cellsize=w.cellsize,capacity=copy(w.capacity)))
  grass=[H.grass!(w,k,s.ticks) for k in eachindex(w.grass)]
  layers=hasproperty(w,:layers) && w.layers!==nothing ? (short=copy(w.layers.short),long=copy(w.layers.long)) : nothing
  push!(frames,(day=day,grass=grass,total=sum(grass),layers=layers))
 end
 write(ARGS[2],JSON3.write((;geometry,frames)))
 println("EXPORTED ",length(frames)," frames")
end
export_grass()
