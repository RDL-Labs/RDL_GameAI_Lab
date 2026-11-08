# Frozen animal-only bridge: INPUT DONOR.jls OUTPUT DAYS [crossing=true] [predators=2].
using JSON3,Serialization,Random,Test
length(ARGS) in (4,5,6) || error("INPUT DONOR OUTPUT DAYS [crossing=true] [predators=2]")
const crossing_output=abspath(ARGS[3]);const crossing_days=parse(Int,ARGS[4])
const crossing_enabled=length(ARGS)==4 || parse(Bool,ARGS[5])
const crossing_predator_count=length(ARGS)<6 ? 2 : parse(Int,ARGS[6])
crossing_predator_count in (0,2) || error("predators must be 0 or 2")
1<=crossing_days<=360 || error("days must be 1..360")
ispath(crossing_output) && error("fresh output required")
const crossing_repo=normpath(joinpath(@__DIR__,"../.."))
const crossing_source=joinpath(crossing_output,"source")
mkpath(joinpath(crossing_source,"experiments"))
cp(joinpath(crossing_repo,"src"),joinpath(crossing_source,"src"))
cp(@__DIR__,joinpath(crossing_source,"experiments/lw_wildlife"))
cp(joinpath(crossing_repo,"Project.toml"),joinpath(crossing_source,"Project.toml"))
include(joinpath(crossing_source,"experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/predator_crossing_layout.jl"))
function crossing_main()
    input=JSON3.read(read(ARGS[1],String));scene=merge((;pairs(input.scene)...),
        (positions=Tuple{Float64,Float64}[],wildlife=merge((;pairs(input.scene.wildlife)...),(count=95,predator_count=0,grass_scale=3.,boundary_gradient=true))))
    s=G.build(scene,input.clock);configured_crossing_layout!(s)
    predators=animal_trial_predators(s)
    # Explicit experiment intervention: remove predators before the first tick.
    # Default 2 preserves the reference run; 0 keeps rabbit/world setup unchanged.
    resize!(predators,crossing_predator_count)
    donor=crossing_predator_count==0 ? nothing : deserialize(ARGS[2])
    dc=donor===nothing ? nothing : donor.state[:predator_cohort]
    minds=PredatorMind[];locals=LocalHunt[];pursuits=PredatorPursuit.(eachindex(predators))
    for i in eachindex(predators)
        m,l=configured_predator_mb_inherit(dc.minds[2],dc.local_hunts[2],i,101,donor.state[:wildlife].ticks)
        m.estimates["crossing_enabled"]=crossing_enabled ? 1. : 0.
        configured_inherit_loop!(pursuits[i].loop,dc.pursuits[2].loop)
        Random.seed!(predators[i].visual.rng,20261106+1000*101+i)
        push!(minds,m);push!(locals,l)
    end
    physiology=PredatorPhysiology.(predators);scents=PredatorScentWorld(length(predators))
    prey_scents=PreyScentWorld(length(predators);cautious=true);rabbit_approach=H.RabbitApproachPolicy()
    cohort=(predators,minds,local_hunts=locals,pursuits,physiology,scents,prey_scents,rabbit_approach)
    conditions=(days=crossing_days,humans=0,predators=length(predators),rabbits=length(s.alive),layout=CROSSING_LAYOUT,
        crossing_enabled,crossing=PREDATOR_CROSSING,rabbit_H=true,grass_scale=3.,nutrition=1.5,
        predator_energy=PREDATOR_ANIMAL_TRIAL,
        donor=donor===nothing ? nothing : abspath(ARGS[2]),donor_index=donor===nothing ? nothing : 2,human_scent=false,boundary=true,
        predator_removal=crossing_predator_count==0,
        fixed=crossing_predator_count==0 ? "20 west / 80 east family-preserving spawn; predators removed before first tick; rabbit rules unchanged" : "20 west / 80 east family-preserving spawn; inherited predator MB; exact river geometry proposal; water movement continues to shore; no current/depth/drowning model; rabbit swimming unchanged",
        stop="requested duration; continue ecology after predator extinction; existing accounting/allocation safety stops retained")
    write(joinpath(crossing_output,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions));flush(stdout)
    cp(ARGS[1],joinpath(crossing_output,"input-origin.json"))
    mkpath(joinpath(crossing_output,"checkpoints"))
    serialize(joinpath(crossing_output,"checkpoints/day-000.jls"),(world=s,cohort=cohort))
    counts=[Dict("selected"=>0,"arrived"=>0,"failed"=>0,"interrupted"=>0,"swim_ticks"=>0) for _ in eachindex(predators)]
    crossing_records=Any[];daily=Any[];started=time()
    timing=@timed for t in 0:crossing_days*17280-1
        sequences=[m.loop.sequence for m in minds];completed=[m.completed for m in minds]
        animal_trial_prepare!(s,predators,t;scents,minds,prey_scents,motion_speed=true,local_hunts=locals,physiology,pursuits)
        for i in eachindex(predators)
            m=minds[i];p=predators[i]
            if m.loop.sequence!=sequences[i] && p.mode==:cross_river
                counts[i]["selected"]+=1
                push!(crossing_records,(event="choice",tick=t,actor=i,H=m.loop.H,food=p.food,candidate=deepcopy(m.selected)))
            end
            if m.completed!=completed[i] && startswith(m.records[end]["method"],"cross:")
                status=m.records[end]["status"];counts[i][status=="achieved" ? "arrived" : status]+=1
                push!(crossing_records,(event="result",actor=i,record=deepcopy(m.records[end])))
            end
            p.alive && p.mode==:cross_river && crossing_water(s.world,(p.visual.body.x,p.visual.body.z)) && (counts[i]["swim_ticks"]+=1)
        end
        animal_trial_advance!(s,predators,t;scents,minds,prey_nutrition=1.5,prey_scents,local_hunts=locals,physiology,pursuits,grazing_policy=rabbit_approach)
        if (t+1)%17280==0
            day=div(t+1,17280)
            report=animal_trial_report(s,predators;scents,minds)
            west(p)=p[1]<12+5sin((p[2]-6)/22+s.world.phase)
            rabbit_west=count(i->s.alive[i] && west((s.animals.x[i],s.animals.z[i])),eachindex(s.alive))
            row=(day,elapsed_seconds=time()-started,rabbits=report.rabbits.alive,starvation=report.rabbits.starvation_deaths,
                births=report.rabbits.reproduction.births,pregnant=report.rabbits.reproduction.pregnant,
                conceptions=report.rabbits.reproduction.conceptions,lost_pregnancies=report.rabbits.reproduction.lost_pregnancies,
                grass_remaining=report.rabbits.grass_remaining,grass_grown=report.rabbits.grass_grown,grass_eaten=report.rabbits.grass_eaten,
                rabbit_west,rabbit_east=report.rabbits.alive-rabbit_west,
                predators=report.predators,crossing=deepcopy(counts),physiology=predator_physiology_report.(physiology))
            push!(daily,row)
            write(joinpath(crossing_output,"progress.json"),JSON3.write(row))
            open(joinpath(crossing_output,"daily.jsonl"),"a") do io;println(io,JSON3.write(row));end
            serialize(joinpath(crossing_output,"checkpoints","day-"*lpad(day,3,'0')*".jls"),(world=s,cohort=cohort,counts=counts))
            println("DAY ",day," rabbits=",row.rabbits," predators=",[p.alive for p in predators]," crossing=",counts);flush(stdout)
        end
    end
    saved=deserialize(joinpath(crossing_output,"checkpoints","day-"*lpad(crossing_days,3,'0')*".jls"))
    @test saved.counts==counts
    @test Set(keys(saved.cohort.rabbit_approach.actors))==Set(keys(rabbit_approach.actors))
    write(joinpath(crossing_output,"result.json"),JSON3.write((conditions,daily,crossing_records,seconds=timing.time,bytes=timing.bytes,gc_seconds=timing.gctime)))
    write(joinpath(crossing_output,"completed.json"),JSON3.write((days=crossing_days,verified=true,seconds=timing.time)))
end
crossing_main()
