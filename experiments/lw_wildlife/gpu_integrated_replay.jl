using Serialization,JSON3,Test,Statistics,SHA
include("predator_generations.jl")
function run_ticks!(saved,ticks)
 s=saved.world;c=saved.cohort
 for t in s.ticks:s.ticks+ticks-1
  animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
  animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
 end
end
function digest(saved)
 io=IOBuffer();serialize(io,saved);bytes2hex(sha256(take!(io)))
end
function main()
 checkpoint=ARGS[1];output=ARGS[2];ticks=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 17280
 original=deserialize(checkpoint);@assert isempty(original.cohort.predators)
 rows=Any[];reference=nothing
 for mode in ("cpu","batch_cpu","gpu_audit","gpu","cpu","batch_cpu","gpu","cpu","batch_cpu","gpu")
  warm=deepcopy(original)
  mode!="cpu" && H.enable_rabbit_neighbor_batch!(warm.world.world;gpu=mode!="batch_cpu",audit=mode=="gpu_audit")
  run_ticks!(warm,min(ticks,128));H.disable_rabbit_neighbor_gpu!()
  saved=deepcopy(original)
  mode!="cpu" && H.enable_rabbit_neighbor_batch!(saved.world.world;gpu=mode!="batch_cpu",audit=mode=="gpu_audit")
  GC.gc();timing=@timed run_ticks!(saved,ticks)
  stats=H.rabbit_neighbor_stats();H.disable_rabbit_neighbor_gpu!()
  signature=digest(saved)
  if reference===nothing;reference=signature;end
  @test signature==reference
  row=(mode,ticks,seconds=timing.time,bytes=timing.bytes,gc_seconds=timing.gctime,signature,identical=signature==reference,stats,alive=count(saved.world.alive),births=saved.world.life.births,deaths=saved.world.deaths)
  push!(rows,row);println(JSON3.write(row));flush(stdout)
  write(output,JSON3.write((checkpoint,ticks,rows,complete=false)))
 end
 write(output,JSON3.write((checkpoint,ticks,rows,complete=true)))
end
main()
