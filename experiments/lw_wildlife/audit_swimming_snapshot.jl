using Serialization,JSON3,Test
root=ARGS[1];current=length(ARGS)>=3 && ARGS[3]=="current"
include(current ? joinpath(@__DIR__,"predator_generations.jl") : joinpath(root,"source/experiments/lw_wildlife/predator_generations.jl"))
saved=deserialize(joinpath(root,"checkpoints/day-147.jls"));s=saved.world;c=saved.cohort
H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
for t in s.ticks:s.ticks+17280-1
 animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
 animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
end
rows=Any[]
for i in eachindex(s.alive)
 p=(s.animals.x[i],s.animals.z[i]);H.clear(s.world,p,p) && continue
 push!(rows,(id=i,alive=s.alive[i],position=p,energy=s.animals.energy[i],water=H.material(s.world.phase,p...)==H.WATER,geometry_clear=H.configured_rabbit_swim_clear(s.world,p,p),trip=get(c.rabbit_approach.trips,i,nothing)))
end
write(ARGS[2],JSON3.write(rows));println(JSON3.write(rows));H.disable_rabbit_neighbor_gpu!()

if current
 @test length(rows)==1 && rows[1].id==2189 && rows[1].alive && rows[1].water && rows[1].geometry_clear
 @test_throws AssertionError G.snapshot(s)
 report=animal_trial_report(s,c.predators;scents=c.scents,minds=c.minds,swimming_policy=c.rabbit_approach)
 @test report.rabbits.alive==count(s.alive)
 i=2189;p=c.rabbit_approach
 @test H.configured_rabbit_swim_position_valid(p,s.world,s.animals,i)
 trip=pop!(p.trips,i)
 @test !H.configured_rabbit_swim_position_valid(p,s.world,s.animals,i)
 p.trips[i]=trip
 obstacle=H.RDLMigrationProbe.Circle(s.animals.x[i],s.animals.z[i],1.)
 push!(s.world.obstacles,obstacle)
 @test !H.configured_rabbit_swim_position_valid(p,s.world,s.animals,i)
 pop!(s.world.obstacles)
 println("SWIMMING SNAPSHOT CHECKS PASS")
end
