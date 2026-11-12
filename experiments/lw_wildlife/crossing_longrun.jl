# Frozen animal-only bridge: INPUT DONOR.jls OUTPUT DAYS [crossing=true] [predators=2] [grass_scale=3] [population_checkpoint|none] [rabbit_swimming=false] [neighbor_backend=cpu|batch_cpu|gpu|gpu_audit|auto|auto_audit] [initial_profile=baseline|diverse] [grass_initial_profile=full|patchy] [layout=distributed|legacy] [grass_model=layered|single] [predator_population=fixed|ratio] [prey_nutrition=1.5] [raptor=false] [initial_rabbits=100].
using JSON3,Serialization,Random,Test
length(ARGS) in (4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22) || error("INPUT DONOR OUTPUT DAYS [crossing=true] [predators=2] [grass_scale=3] [population_checkpoint|none] [rabbit_swimming=false] [neighbor_backend=cpu|batch_cpu|gpu|gpu_audit|auto|auto_audit] [initial_profile=baseline|diverse] [grass_initial_profile=full|patchy] [layout=distributed|legacy] [grass_model=layered|single] [predator_population=fixed|ratio] [prey_nutrition=1.5] [raptor=false] [initial_rabbits=100]")
const initial_rabbit_count=length(ARGS)>=18 ? parse(Int,ARGS[18]) : 100
100<=initial_rabbit_count<=10000 || error("initial rabbits must be 100..10000")
const predator_composition_enabled=length(ARGS)>=22 && parse(Bool,ARGS[22])
const scat_enabled=length(ARGS)>=20 && parse(Bool,ARGS[20])
const raptor_prey_nutrition=length(ARGS)>=21 ? parse(Float64,ARGS[21]) : 1.
isfinite(raptor_prey_nutrition) && raptor_prey_nutrition>0 || error("invalid raptor nutrition")
const raptor_enabled=length(ARGS)>=17 && parse(Bool,ARGS[17])
const crossing_output=abspath(ARGS[3]);const crossing_days=parse(Int,ARGS[4])
const crossing_stop_on_death=length(ARGS)>=19 ? parse(Bool,ARGS[19]) : crossing_days==0
const crossing_enabled=length(ARGS)==4 || parse(Bool,ARGS[5])
const predator_population_mode=length(ARGS)>=15 ? ARGS[15] : "fixed"
predator_population_mode in ("fixed","ratio","replace") || error("unknown predator population mode")
const crossing_prey_nutrition=length(ARGS)>=16 ? parse(Float64,ARGS[16]) : 1.5
isfinite(crossing_prey_nutrition) && crossing_prey_nutrition>0 || error("prey nutrition must be finite and positive")
const crossing_predator_count=length(ARGS)<6 ? 2 : parse(Int,ARGS[6])
# World resource condition: scales capacity, initial grass and capacity-based regrowth.
# Default 3 preserves the existing comparison; 1.5 halves supply, not birth rules.
const crossing_grass_scale=length(ARGS)<7 ? 3. : parse(Float64,ARGS[7])
const crossing_population_checkpoint=length(ARGS)<8 || ARGS[8]=="none" ? nothing : abspath(ARGS[8])
const rabbit_swimming_enabled=length(ARGS)>=9 && parse(Bool,ARGS[9])
const rabbit_initial_profile=length(ARGS)>=11 ? ARGS[11] : "baseline"
rabbit_initial_profile in ("baseline","diverse") || error("unknown initial profile")
rabbit_initial_profile=="diverse" && crossing_population_checkpoint!==nothing && error("diverse profile requires fresh world")
const grass_initial_profile=length(ARGS)>=12 ? ARGS[12] : "full"
grass_initial_profile in ("full","patchy") || error("unknown grass profile")
grass_initial_profile=="patchy" && crossing_population_checkpoint!==nothing && error("patchy grass requires fresh world")
const grass_model=length(ARGS)>=14 ? ARGS[14] : "layered"
grass_model in ("layered","single") || error("unknown grass model")
const rabbit_layout_profile=length(ARGS)>=13 ? ARGS[13] : "distributed"
rabbit_layout_profile in ("distributed","legacy") || error("unknown layout")
const rabbit_neighbor_backend=length(ARGS)>=10 ? ARGS[10] : "cpu"
rabbit_neighbor_backend in ("cpu","batch_cpu","gpu","gpu_audit","auto","auto_audit") || error("unknown neighbor backend")
isfinite(crossing_grass_scale) && crossing_grass_scale>0 || error("grass_scale must be finite and positive")
crossing_predator_count in (0,1,2) || error("predators must be 0, 1 or 2")
# 実験運用上限。身体・認知の閾値ではない。日次STOPと保存を長期試験でも維持。
const CROSSING_MAX_DAYS=3000
0<=crossing_days<=CROSSING_MAX_DAYS || error("days must be 0 (until stopped) or 1..$CROSSING_MAX_DAYS")
ispath(crossing_output) && error("fresh output required")
const crossing_repo=normpath(joinpath(@__DIR__,"../.."))
const crossing_source=joinpath(crossing_output,"source")
mkpath(joinpath(crossing_source,"experiments"))
cp(joinpath(crossing_repo,"src"),joinpath(crossing_source,"src"))
cp(@__DIR__,joinpath(crossing_source,"experiments/lw_wildlife"))
cp(joinpath(crossing_repo,"Project.toml"),joinpath(crossing_source,"Project.toml"))
include(joinpath(crossing_source,"experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/predator_crossing_layout.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/rabbit_diverse_start.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/rabbit_patchy_grass.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/rabbit_distributed_layout.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/predator_population_exchange.jl"))
include(joinpath(crossing_source,"src/lw/configured_paths/raptor_trial.jl"))
function crossing_main()
    input=JSON3.read(read(ARGS[1],String));scene=merge((;pairs(input.scene)...),
        (positions=Tuple{Float64,Float64}[],wildlife=merge((;pairs(input.scene.wildlife)...),(count=initial_rabbit_count-Int(get(input.scene.wildlife,:initial_young_count,0)),predator_count=0,grass_scale=crossing_grass_scale,boundary_gradient=true))))
    population_saved=crossing_population_checkpoint===nothing ? nothing : deserialize(crossing_population_checkpoint)
    if population_saved===nothing
        s=G.build(scene,input.clock)
        count(s.alive)==initial_rabbit_count || error("initial rabbit roster mismatch")
        rabbit_initial_profile=="diverse" && configured_rabbit_diverse_start!(s)
        layout_record=rabbit_layout_profile=="distributed" ? configured_rabbit_distributed_layout!(s) : (configured_crossing_layout!(s);CROSSING_LAYOUT)
    else
        # Continue a predator-free world, optionally introducing two predators.
        # Keep world time, resources, rabbit physiology, RNG, families and learned H.
        predator_population_mode!="fixed" || isempty(population_saved.cohort.predators) || length(population_saved.cohort.predators)==crossing_predator_count || error("cannot change existing predator roster on continuation")
        prior_conditions=JSON3.read(read(joinpath(dirname(dirname(crossing_population_checkpoint)),"conditions.json"),String))
        hasproperty(population_saved,:migration) && population_saved.migration!==nothing && predator_population_mode=="fixed" && error("cannot disable migration on continuation")
        prior_conditions.grass_scale==crossing_grass_scale || error("cannot change grass scale on continuation")
        layout_record=(rule="inherited",)
        s=population_saved.world
        !s.prepared && s.ticks%17280==0 || error("checkpoint must be an unprepared day boundary")
    end
    grass_initial_record=grass_initial_profile=="patchy" ? configured_rabbit_patchy_grass!(s) : nothing
    if population_saved===nothing && grass_model=="layered";H.enable_grass_layers!(s.world);end
    (s.world.layers!==nothing)==(grass_model=="layered") || error("grass model must match checkpoint")
    P.configured_predator_terrain_enable!(s.world;enabled=crossing_enabled)
    start_tick=s.ticks;start_day=div(start_tick,17280)
    preserve_predators=population_saved!==nothing && !isempty(population_saved.cohort.predators)
    if preserve_predators
        saved_cohort=population_saved.cohort
        predators=saved_cohort.predators;minds=saved_cohort.minds;locals=saved_cohort.local_hunts
        pursuits=saved_cohort.pursuits;physiology=saved_cohort.physiology
        all(p->(p isa ComposedPredatorPhysiology)==predator_composition_enabled,physiology) || error("cannot change body composition on continuation")
        scents=saved_cohort.scents;prey_scents=saved_cohort.prey_scents
        donor=nothing
        all(m->get(m.estimates,"crossing_enabled",0.)==(crossing_enabled ? 1. : 0.),minds) || error("cannot change predator crossing on continuation")
    else
    predators=animal_trial_predators(s)
    # Explicit experiment intervention: remove predators before the first tick.
    # Default 2 preserves the reference run; 0 keeps rabbit/world setup unchanged.
    resize!(predators,crossing_predator_count)
    donor=crossing_predator_count==0 || ARGS[2]=="none" ? nothing : deserialize(ARGS[2])
    dc=donor===nothing ? nothing : donor.state[:predator_cohort]
    minds=PredatorMind[];locals=LocalHunt[];pursuits=PredatorPursuit.(eachindex(predators))
    for i in eachindex(predators)
        m,l=dc===nothing ? (PredatorMind(i),LocalHunt(i;probabilistic_capture=true)) : configured_predator_mb_inherit(dc.minds[2],dc.local_hunts[2],i,101,donor.state[:wildlife].ticks)
        m.estimates["crossing_enabled"]=crossing_enabled ? 1. : 0.
        # Donor memories are rebased to the new actor's introduction time.
        if start_tick>0
            m.places=Dict{String,Any}(key=>merge(place,(seen=place.seen+start_tick,)) for (key,place) in m.places)
        end
        dc!==nothing && configured_inherit_loop!(pursuits[i].loop,dc.pursuits[2].loop)
        Random.seed!(predators[i].visual.rng,20261106+1000*101+i)
        push!(minds,m);push!(locals,l)
    end
    physiology=predator_composition_enabled ? ComposedPredatorPhysiology.(predators) : PredatorPhysiology.(predators);scents=PredatorScentWorld(length(predators))
    prey_scents=PreyScentWorld(length(predators);cautious=true)
    end
    rabbit_approach=population_saved===nothing ? H.RabbitApproachPolicy() : population_saved.cohort.rabbit_approach
    if rabbit_swimming_enabled && !(rabbit_approach isa H.RabbitSwimmingPolicy)
        rabbit_approach=H.RabbitSwimmingPolicy(rabbit_approach)
    elseif !rabbit_swimming_enabled && rabbit_approach isa H.RabbitSwimmingPolicy
        error("cannot disable swimming on a swimming checkpoint")
    end
    cohort=(predators,minds,local_hunts=locals,pursuits,physiology,scents,prey_scents,rabbit_approach)
    migration=predator_population_mode!="fixed" ? (population_saved!==nothing && hasproperty(population_saved,:migration) && population_saved.migration!==nothing ? population_saved.migration : PredatorPopulationExchange(length(predators))) : nothing
    migration!==nothing && (predator_population_mode=="replace" ? configured_predator_replacement_update!(s,cohort,migration,start_tick;crossing_enabled,target=crossing_predator_count) : configured_predator_population_update!(s,cohort,migration,start_tick;crossing_enabled))
    rabbit_neighbor_backend!="cpu" && H.enable_rabbit_neighbor_batch!(s.world;gpu=rabbit_neighbor_backend!="batch_cpu",audit=endswith(rabbit_neighbor_backend,"_audit"),automatic=startswith(rabbit_neighbor_backend,"auto"))
    saved_raptor=population_saved!==nothing && hasproperty(population_saved,:raptor) ? population_saved.raptor : nothing
    !raptor_enabled && saved_raptor!==nothing && error("cannot discard saved raptor accounting")
    raptor=raptor_enabled ? (saved_raptor===nothing ? configured_raptor(s,scene) : saved_raptor) : nothing
    saved_scat=population_saved!==nothing && hasproperty(population_saved,:scat_state) ? population_saved.scat_state : nothing
    !scat_enabled && saved_scat!==nothing && error("cannot discard saved scat traces")
    scat_state=scat_enabled ? (saved_scat===nothing ? ScatTraces() : saved_scat) : nothing
    conditions=(predator_composition_enabled,predator_composition_rule=predator_composition_enabled ? PREDATOR_COMPOSITION : nothing,scat_enabled,scat_rule=scat_enabled ? SCAT_TRACE : nothing,scat_cue=scat_enabled ? PREDATOR_SCAT_CUE : nothing,predator_idle_gate=PREDATOR_IDLE_GATE,raptor_prey_nutrition,initial_rabbit_count=population_saved===nothing ? initial_rabbit_count : nothing,raptor_enabled,raptor_fixed="optional single-bird FSM; daily global rabbit count arrival>=150/departure<=100; exact tree list; 2D elevated sight; no MB; resting observation off; leftovers recorded only; outside body reset on return",raptor_rule=raptor_enabled ? RAPTOR_TRIAL : nothing,predator_terrain=(enabled=crossing_enabled,rule=P.PREDATOR_TERRAIN),predator_population_mode,predator_population_rule=migration===nothing ? nothing : PREDATOR_POPULATION_EXCHANGE,predator_population_fixed="replace: day-boundary refill to requested live count, fresh IDs and memories, rabbits>=replacement_min_rabbits required; ratio only: global live rabbit count; daily arrivals at 100+50*(k-1), departures at N<=50*k; instantaneous edge immigration and off-map emigration; fresh entrant MB; no off-map simulation",rabbit_burrow_refuge=G.RABBIT_BURROW_REFUGE,rabbit_nursing_alert=G.RABBIT_NURSING_ALERT,rabbit_nursing_goal=G.RABBIT_NURSING_GOAL,rabbit_exponential_candidates=H.RABBIT_EXPONENTIAL_CANDIDATES,rabbit_food_cooling=H.RABBIT_FOOD_COOLING,rabbit_food_search=H.RABBIT_FOOD_SEARCH,rabbit_food_pressure=H.RABBIT_FOOD_PRESSURE,rabbit_food_pressure_gate=H.RABBIT_FOOD_PRESSURE_GATE,rabbit_food_pressure_connection=H.RABBIT_FOOD_PRESSURE_CONNECTION,rabbit_local_rho=H.RABBIT_LOCAL_RHO,rabbit_juvenile_growth=G.RABBIT_JUVENILE_GROWTH,rabbit_nest_boundary=G.RABBIT_NEST_BOUNDARY,rabbit_grazing_motion=H.RABBIT_GRAZING_MOTION,grass_model,grass_layers=H.GRASS_LAYERS,rabbit_grass_layers=H.RABBIT_GRASS_LAYERS,rabbit_sparse_departure=H.RABBIT_SPARSE_DEPARTURE,rabbit_cover_foraging=H.RABBIT_COVER_FORAGING,preserve_predators,initial_profiles_inherited=population_saved===nothing ? nothing : (rabbit=get(prior_conditions,:rabbit_initial_profile,"unknown"),grass=get(prior_conditions,:grass_initial_profile,"unknown")),rabbit_nest_preparation=G.RABBIT_NEST_PREPARATION,rabbit_birth_timing=G.RABBIT_BIRTH_TIMING,rabbit_maternal_boundary=G.RABBIT_MATERNAL_BOUNDARY,grass_initial_profile,grass_initial_parameters=grass_initial_profile=="patchy" ? RABBIT_PATCHY_GRASS : nothing,grass_initial_record,rabbit_initial_profile,initial_profile_parameters=rabbit_initial_profile=="diverse" ? RABBIT_DIVERSE_START : nothing,rabbit_reproductive_condition=G.RABBIT_REPRODUCTIVE_CONDITION,rabbit_breeding_season=G.RABBIT_BREEDING_SEASON,rabbit_neighbor_backend,gpu_min_queries=H.RABBIT_NEIGHBOR_GPU_MIN_QUERIES,neighbor_gpu_scope="static obstacle neighbor visibility only; CPU river/grass/H/choice; Float32 gap with CPU boundary fallback",stop_on_predator_death=crossing_stop_on_death,days=crossing_days,start_day,end_day=crossing_days==0 ? nothing : start_day+crossing_days,
        population_checkpoint=crossing_population_checkpoint,
        initial_births=s.life.births,initial_starvation=s.deaths,
        humans=0,predators=migration===nothing ? length(predators) : count(i->migration.present[i] && predators[i].alive,eachindex(predators)),predator_slots=length(predators),rabbits=count(s.alive),layout=layout_record,
        rabbit_swimming_enabled,rabbit_swimming=H.RABBIT_SWIMMING,
        rabbit_terrain=H.RABBIT_TERRAIN,rabbit_swimming_fixed="terrain mode uses ordinary goal movement; legacy random crossing disabled for new trips; optional configured candidate; exact river geometry; no opposite-bank food lookup; hunger/current food-goal H/local grass weighting; food-goal H resets on achieved intake; historical cell H excluded; shore overrides interrupt; water commits to landing; no drowning/current/temperature",
        crossing_enabled,crossing=PREDATOR_CROSSING,rabbit_H=true,nest_grazing_avoidance=false,rabbit_burrow=G.RABBIT_BURROW,nursing_plan=G.RABBIT_NURSING_PLAN,grass_scale=crossing_grass_scale,nutrition=crossing_prey_nutrition,
        predator_energy=PREDATOR_ANIMAL_TRIAL,adult_prey_energy=PREDATOR_ANIMAL_TRIAL.adult_food*crossing_prey_nutrition,adult_prey_basal_days=PREDATOR_ANIMAL_TRIAL.adult_food*crossing_prey_nutrition/PREDATOR_ANIMAL_TRIAL.daily_food,
        donor=donor===nothing ? nothing : abspath(ARGS[2]),donor_index=donor===nothing ? nothing : 2,human_scent=false,boundary=true,
        predator_removal=migration===nothing && crossing_predator_count==0,
        introduction=migration!==nothing ? "daily hysteretic ratio controller; fresh immigrant MB at walkable map edge; departures archived alive at last observation, outside simulation" : preserve_predators ? "exact existing cohort continuation; bodies, memories, RNG, scents, pursuits retained" : population_saved===nothing ? nothing : crossing_predator_count==0 ? "predator-free continuation; existing world/rabbit state preserved; no relocation" : "requested predators at existing trial spawn sites; inherited donor MB; existing rabbit/world clocks and H preserved; no rabbit relocation",
        fixed=migration!==nothing ? "global rabbit count: arrivals at 100+50*(k-1), departures at N<=50*k; daily hysteretic instantaneous immigration/emigration; no outside ecology or walking to exit" : preserve_predators ? "no respawn or initial profile reapplication; current configured behaviors retained" : population_saved!==nothing && crossing_predator_count==0 ? "saved population without respawn; configured juvenile burrow; no maternal grazing repulsion" : crossing_predator_count==0 ? "capacity-weighted distributed or legacy family-preserving spawn; predators removed before first tick; rabbit rules unchanged" : "capacity-weighted distributed or legacy family-preserving spawn; optional donor MB (none means fresh); exact river geometry proposal; water is costly terrain; ordinary movement/reconsideration; no current/depth/drowning model; rabbit swimming separately controlled by rabbit_swimming_enabled",
        stop=crossing_days==0 ? "day boundary: STOP file or any ground predator death; no duration limit; existing safety errors retained" : "requested duration; continue ecology after predator extinction; existing accounting/allocation safety stops retained")
    write(joinpath(crossing_output,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions));flush(stdout)
    cp(ARGS[1],joinpath(crossing_output,"input-origin.json"))
    mkpath(joinpath(crossing_output,"checkpoints"))
    serialize(joinpath(crossing_output,"checkpoints/day-000.jls"),(world=s,cohort=cohort,migration=migration,raptor=raptor,scat_state=scat_state))
    counts=preserve_predators && hasproperty(population_saved,:counts) ? deepcopy(population_saved.counts) : [Dict("selected"=>0,"arrived"=>0,"failed"=>0,"interrupted"=>0,"swim_ticks"=>0) for _ in eachindex(predators)]
    while length(counts)<length(predators);push!(counts,Dict("selected"=>0,"arrived"=>0,"failed"=>0,"interrupted"=>0,"swim_ticks"=>0));end
    crossing_records=Any[];daily=Any[];started=time()
    stop_reason="duration";completed_days=0
    timing=@timed for t in start_tick:(crossing_days==0 ? typemax(Int)-1 : start_tick+crossing_days*17280-1)
        if migration!==nothing
            predator_population_mode=="replace" ? configured_predator_replacement_update!(s,cohort,migration,t;crossing_enabled,target=crossing_predator_count) : configured_predator_population_update!(s,cohort,migration,t;crossing_enabled)
            while length(counts)<length(predators);push!(counts,Dict("selected"=>0,"arrived"=>0,"failed"=>0,"interrupted"=>0,"swim_ticks"=>0));end
        end
        if raptor!==nothing && t%RAPTOR_TRIAL.day_ticks==0
            raptor_was_present=raptor.present
            configured_raptor_population!(raptor,count(s.alive),t)
            if !raptor_was_present && raptor.present
                raptor.visual.body.x,raptor.visual.body.z=configured_raptor_edge(s.world,raptor.destination)
            elseif raptor.mode==:depart
                raptor.destination=configured_raptor_edge(s.world,(raptor.visual.body.x,raptor.visual.body.z))
            end
        end
        sequences=[m.loop.sequence for m in minds];completed=[m.completed for m in minds]
        animal_trial_prepare!(s,predators,t;scat_state,raptor,scents,minds,prey_scents,motion_speed=true,local_hunts=locals,physiology,pursuits,present=migration===nothing ? nothing : migration.present)
        for i in eachindex(predators)
            migration!==nothing && !migration.present[i] && continue
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
        animal_trial_advance!(s,predators,t;scat_state,scents,minds,prey_nutrition=crossing_prey_nutrition,prey_scents,local_hunts=locals,physiology,pursuits,grazing_policy=rabbit_approach,present=migration===nothing ? nothing : migration.present)
        raptor!==nothing && configured_raptor_step!(raptor,s,predators,t;prey_nutrition=raptor_prey_nutrition,present=migration===nothing ? nothing : migration.present)
        if (t+1)%17280==0
            absolute_day=div(t+1,17280);day=absolute_day-start_day
            report=animal_trial_report(s,predators;raptor,scents,minds,swimming_policy=rabbit_approach)
            west(p)=p[1]<12+5sin((p[2]-6)/22+s.world.phase)
            rabbit_west=count(i->s.alive[i] && west((s.animals.x[i],s.animals.z[i])),eachindex(s.alive))
            row=(scat=scat_state===nothing ? nothing : configured_scat_report(scat_state),raptor=raptor===nothing ? nothing : configured_raptor_report(raptor),predator_population=migration===nothing ? nothing : merge(configured_predator_population_report(cohort,migration,count(s.alive)),(mode=predator_population_mode,target=predator_population_mode=="replace" ? crossing_predator_count : configured_predator_population_target(count(s.alive),count(i->migration.present[i] && predators[i].alive,eachindex(predators))))),nursing_alert=copy(G.RABBIT_NURSING_ALERT_STATS),nursing_pending=s.life===nothing ? 0 : length(G.configured_nursing_pending(s.life)),candidate_work=copy(H.RABBIT_CANDIDATE_STATS),food_pressure=H.rabbit_food_pressure_snapshot(rabbit_approach),local_rho=H.rabbit_rho_snapshot(rabbit_approach),grazing_motion=copy(H.RABBIT_GRAZING_MOTION_STATS),neighbor_gpu=H.rabbit_neighbor_stats(),day,absolute_day,elapsed_seconds=time()-started,rabbits=report.rabbits.alive,starvation=report.rabbits.starvation_deaths,starvation_breakdown=report.rabbits.starvation_breakdown,
                births=report.rabbits.reproduction.births,pregnant=report.rabbits.reproduction.pregnant,
                conceptions=report.rabbits.reproduction.conceptions,lost_pregnancies=report.rabbits.reproduction.lost_pregnancies,
                grass_layers=report.rabbits.grass_layers,grass_remaining=report.rabbits.grass_remaining,grass_grown=report.rabbits.grass_grown,grass_eaten=report.rabbits.grass_eaten,
                rabbit_west,rabbit_east=report.rabbits.alive-rabbit_west,
                rabbit_swimming=rabbit_swimming_enabled ? deepcopy(rabbit_approach.counts) : nothing,
                predators=migration===nothing ? report.predators : [merge(report.predators[i],(present=migration.present[i],status=!migration.present[i] ? "outside" : predators[i].alive ? "resident" : "dead")) for i in eachindex(predators)],crossing=deepcopy(counts),physiology=predator_physiology_report.(physiology))
            crossing_days!=0 && push!(daily,row) # Unbounded runs stream daily rows to disk.
            write(joinpath(crossing_output,"progress.json"),JSON3.write(row))
            open(joinpath(crossing_output,"daily.jsonl"),"a") do io;println(io,JSON3.write(row));end
            serialize(joinpath(crossing_output,"checkpoints","day-"*lpad(day,3,'0')*".jls"),(world=s,cohort=cohort,counts=counts,migration=migration,raptor=raptor,scat_state=scat_state))
            completed_days=day
            println("DAY ",day," rabbits=",row.rabbits," predators=",migration===nothing ? [p.alive for p in predators] : row.predator_population," crossing=",counts);flush(stdout)
            if isfile(joinpath(crossing_output,"STOP")) || (predator_population_mode!="replace" && crossing_stop_on_death && any(p->!p.alive,predators))
                stop_reason=isfile(joinpath(crossing_output,"STOP")) ? "manual_stop" : "predator_death"
                break
            end
        end
    end
    neighbor_gpu=H.rabbit_neighbor_stats();H.disable_rabbit_neighbor_gpu!()
    saved=deserialize(joinpath(crossing_output,"checkpoints","day-"*lpad(completed_days,3,'0')*".jls"))
    @test saved.counts==counts
    @test Set(keys(H.rabbit_approach_base(saved.cohort.rabbit_approach).actors))==Set(keys(H.rabbit_approach_base(rabbit_approach).actors))
    write(joinpath(crossing_output,"result.json"),JSON3.write((conditions,daily,migration_events=migration===nothing ? nothing : migration.events,crossing_records,neighbor_gpu,seconds=timing.time,bytes=timing.bytes,gc_seconds=timing.gctime)))
    write(joinpath(crossing_output,"completed.json"),JSON3.write((days=completed_days,start_day,end_day=start_day+completed_days,stop_reason,verified=true,seconds=timing.time)))
end
crossing_main()
