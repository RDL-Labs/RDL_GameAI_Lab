using Serialization,JSON3,Test
include("predator_generations.jl")
include("../../src/lw/configured_paths/predator_population_exchange.jl")
const terrain_source_run="C:/Users/ken_m/Documents/Codex/predator-one-nutrition1-continue360d-20261110"
function terrain_replay(enabled;checkpoint_day=71)
    saved=deserialize(joinpath(terrain_source_run,"checkpoints/day-"*lpad(checkpoint_day,3,'0')*".jls"))
    s=saved.world;c=saved.cohort;p=c.predators[1]
    P.configured_predator_terrain_enable!(s.world;enabled)
    H.enable_rabbit_neighbor_batch!(s.world;gpu=true,automatic=true)
    rows=Any[];start_tick=s.ticks;first_dry_after_water=nothing;entered_water=crossing_water(s.world,(p.visual.body.x,p.visual.body.z))
    duration=@elapsed for t in start_tick:165*17280-1
        animal_trial_prepare!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,
            motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits)
        animal_trial_advance!(s,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,
            prey_nutrition=1.,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach)
        wet=crossing_water(s.world,(p.visual.body.x,p.visual.body.z))
        entered_water |= wet
        entered_water && !wet && first_dry_after_water===nothing && (first_dry_after_water=t)
        if (t+1)%17280==0
            push!(rows,(day=div(t+1,17280),alive=p.alive,food=p.food,captures=p.visual.body.captures,
                position=(p.visual.body.x,p.visual.body.z),blocked=p.visual.body.blocked,mode=p.mode,
                rabbits=count(s.alive),water=wet))
        end
    end
    H.disable_rabbit_neighbor_gpu!()
    (enabled,checkpoint_day,seconds=duration,entered_water,first_dry_after_water,rows)
end
function terrain_checks()
    s,predators=animal_trial_world()
    w=deepcopy(s.world);empty!(w.obstacles)
    origin=(12+5sin(w.phase),6.);b=deepcopy(predators[1].visual.body)
    b.x,b.z=origin;b.heading=0.;b.distance=0.
    @test !P.configured_predator_terrain_clear(w,origin,origin)
    P.configured_predator_terrain_enable!(w)
    @test P.configured_predator_terrain_clear(w,origin,origin)
    @test P.move!(w,b,.5;turn=false)
    @test b.distance≈P.PREDATOR_TERRAIN.water_speed
    @test P.configured_predator_terrain_extra_distance(w,origin,(b.x,b.z))≈.36
    @test !configured_predator_water_crossing(w,origin,(b.x,b.z))
    mind=PredatorMind(1);mind.selected=LW.D("action"=>:cross_river)
    p=deepcopy(predators[1]);p.visual.body=b
    @test !configured_crossing_committed(w,mind,p)
    rows=Any[];configured_crossing_candidate!(rows,mind,p,w)
    @test isempty(rows)
    # World energy charge uses actual water distance once; no crossing surcharge.
    p.mode=:visit_food;before_food=p.food
    configured_trial_advance!((world=w,),p,0;scent_speed=.22)
    @test before_food-p.food≈PREDATOR_ANIMAL_TRIAL.daily_food/17280+.12*.1*4
    push!(w.obstacles,H.RDLMigrationProbe.Circle(b.x+.1,b.z,.4))
    @test !P.configured_predator_terrain_clear(w,(b.x,b.z),(b.x+.1,b.z))
end
@testset "costly predator terrain" begin
    terrain_checks()
end
old=terrain_replay(false);new=terrain_replay(true);stuck=terrain_replay(true;checkpoint_day=72)
@test !old.rows[end].alive
@test old.rows[end].captures==97
@test old.rows[end].position==(12.867460124226957,5.520246574877179)
@test new.rows[end].alive && new.first_dry_after_water!==nothing
@test stuck.rows[end].alive && stuck.first_dry_after_water!==nothing
println(JSON3.write((;old,new,stuck)))
write("C:/Users/ken_m/Documents/Codex/predator-terrain-replay-20261110.json",JSON3.write((;old,new,stuck)))
