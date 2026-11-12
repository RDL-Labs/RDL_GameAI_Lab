using JSON3,Serialization,Test
const root=ARGS[1];const frozen=length(ARGS)>=3 ? ARGS[3] : joinpath(root,"source")
include(joinpath(frozen,"experiments/lw_wildlife/predator_generations.jl"))
for name in ("predator_crossing_layout","rabbit_diverse_start","rabbit_patchy_grass","rabbit_distributed_layout","predator_population_exchange","raptor_trial")
    include(joinpath(frozen,"src/lw/configured_paths",name*".jl"))
end
function audit()
    saved=deserialize(joinpath(root,"checkpoints/day-054.jls"));s=saved.world;c=saved.cohort
    P.configured_predator_terrain_enable!(s.world;enabled=true)
    H.enable_rabbit_neighbor_batch!(s.world;gpu=false,audit=false,automatic=false)
    p=c.predators[1];m=c.minds[1];stats=Dict{String,Int}();distance=0.;hours=Any[];records=Any[]
    start_spent=p.spent;start_eaten=p.eaten;initial_estimates=copy(m.estimates);choices=Any[]
    for t in s.ticks:55*17280-1
        configured_predator_replacement_update!(s,c,saved.migration,t;target=1)
        bird=saved.raptor
        if t%17280==0
            was=bird.present;configured_raptor_population!(bird,count(s.alive),t)
            if !was && bird.present
                bird.visual.body.x,bird.visual.body.z=configured_raptor_edge(s.world,bird.destination)
            elseif bird.mode==:depart
                bird.destination=configured_raptor_edge(s.world,(bird.visual.body.x,bird.visual.body.z))
            end
        end
        sequence=m.loop.sequence;completed=m.completed
        animal_trial_prepare!(s,c.predators,t;scat_state=saved.scat_state,raptor=bird,scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,present=saved.migration.present)
        m.loop.sequence!=sequence && push!(choices,(tick=t,candidate=deepcopy(m.selected)))
        m.completed!=completed && push!(records,deepcopy(m.records[end]))
        x,z=p.visual.body.x,p.visual.body.z;mode=string(p.mode)
        animal_trial_advance!(s,c.predators,t;scat_state=saved.scat_state,scents=c.scents,minds=c.minds,prey_nutrition=.5,prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,grazing_policy=c.rabbit_approach,present=saved.migration.present)
        configured_raptor_step!(bird,s,c.predators,t;prey_nutrition=.5,present=saved.migration.present)
        step=hypot(p.visual.body.x-x,p.visual.body.z-z);distance+=step
        key=mode*(step<1e-9 ? ":stationary" : ":moving");stats[key]=get(stats,key,0)+1
        if t%720==0 || !p.alive && get(stats,"death_recorded",0)==0
            push!(hours,(tick=t,food=p.food,spent=p.spent-start_spent,eaten=p.eaten-start_eaten,position=(p.visual.body.x,p.visual.body.z),distance,mode,body_state=Int(p.visual.body.state),H=m.loop.H))
            !p.alive && (stats["death_recorded"]=1)
        end
    end
    expected=deserialize(joinpath(root,"checkpoints/day-055.jls"))
    matches=JSON3.write(trial_predator_report(p))==JSON3.write(trial_predator_report(expected.cohort.predators[1]))
    out=(initial_estimates,final_estimates=m.estimates,choices,matches,stats,distance,spent=p.spent-start_spent,eaten=p.eaten-start_eaten,hours,records,local_counts=c.local_hunts[1].counts,local_records=c.local_hunts[1].records,pursuit=c.pursuits[1].records)
    write(ARGS[2],JSON3.write(out));println(JSON3.write((matches,stats,distance,spent=out.spent,eaten=out.eaten)))
    length(ARGS)<3 && @test matches
end
audit()


