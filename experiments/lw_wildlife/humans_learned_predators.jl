# Experimental bridge only. Human policy stays unchanged; no attacks on humans.
# Usage: INPUT DONOR_GENERATION NEW_OUTPUT DAYS [DONOR_INDEX=2] [HUMAN_SCENT=false] [RABBIT_H=false]
# DONOR_INDEX=0 starts fresh MBs; donor directory is not read in that mode.
# DONOR_GENERATION also accepts an integrated checkpoint .jls file.
using JSON3, Serialization, SHA, Test
length(ARGS) in 4:10 || error("INPUT DONOR_GENERATION NEW_OUTPUT DAYS [DONOR_INDEX] [HUMAN_SCENT=false] [RABBIT_H=false] [CURRENT_ECOLOGY=false] [BACKEND=auto] [CHECKPOINT_INTERVAL=1]")
const current_ecology=length(ARGS)>=8 && parse(Bool,ARGS[8])
const integrated_backend=length(ARGS)>=9 ? ARGS[9] : "auto"
integrated_backend in ("auto","batch_cpu") || error("backend must be auto or batch_cpu")
const integrated_save_interval=length(ARGS)>=10 ? parse(Int,ARGS[10]) : 1
integrated_save_interval>0 || error("positive checkpoint interval required")
# 暫定固定の比較実験設定。第8引数のみで有効。通常判断を変更しない。
const integrated_ecology_setup=(rabbits=150,predators=1,grass_scale=1.5,prey_nutrition=1.0)
const integrated_predator_count=current_ecology ? integrated_ecology_setup.predators : 2
const human_source_input=abspath(ARGS[1]);const donor_directory=abspath(ARGS[2])
const integrated_output=abspath(ARGS[3]);const requested_days=parse(Int,ARGS[4])
const selected_donor=length(ARGS)>=5 ? parse(Int,ARGS[5]) : 2
const human_scent_enabled=length(ARGS)>=6 ? parse(Bool,ARGS[6]) : false
const rabbit_approach_enabled=length(ARGS)>=7 ? parse(Bool,ARGS[7]) : false
0<=requested_days<=180 || error("days: 0 means manual stop, otherwise 1..180")
const integrated_unlimited=requested_days==0
# 実験運用のみ。0は日数制限なし。身体・学習・一日の長さには影響しない。
integrated_ticks(start_sec,days,clock)=integrated_unlimited ? Iterators.countfrom(start_sec) : start_sec:days*div(clock.day_us,1_000_000)-1
ispath(integrated_output) && error("fresh output required")
const repository=normpath(joinpath(@__DIR__,"../.."))
const frozen_root=joinpath(integrated_output,"source")
mkpath(joinpath(frozen_root,"experiments/lw_wildlife"));mkpath(joinpath(frozen_root,"integrations"))
cp(joinpath(repository,"src"),joinpath(frozen_root,"src"))
cp(joinpath(repository,"integrations/lightweight_julia"),joinpath(frozen_root,"integrations/lightweight_julia"))
for name in ("animals_only.jl","prey_scent_compare.jl","predator_generations.jl","predator_3d_spec.json","humans_learned_predators.jl","proximity_observer.jl")
    cp(joinpath(@__DIR__,name),joinpath(frozen_root,"experiments/lw_wildlife",name))
end
cp(joinpath(repository,"Project.toml"),joinpath(frozen_root,"Project.toml"))
const human_input=JSON3.read(read(human_source_input,String),Dict{String,Any})
human_input["config"]["days"]=integrated_unlimited ? 1 : requested_days
const human_roster=String.(human_input["scene"]["experimental_actor_ids"])
@assert length(unique(human_roster))==length(human_roster)
@assert all(length(human_input["scene"][k])==length(human_roster) for k in ("positions","reserve","initial_inventory"))
# Provisional world setup and explicit learned-MB copying, not natural reproduction.
human_input["scene"]["wildlife"]=merge(human_input["scene"]["wildlife"],
    Dict("enabled"=>true,"count"=>95,"predator_count"=>0,"grass_scale"=>3.,"boundary_gradient"=>true))
if current_ecology
    selected_donor==0 && rabbit_approach_enabled || error("current ecology requires fresh predator MB and rabbit H")
    human_input["scene"]["wildlife"]["count"]=integrated_ecology_setup.rabbits-get(human_input["scene"]["wildlife"],"initial_young_count",0)
    human_input["scene"]["wildlife"]["grass_scale"]=integrated_ecology_setup.grass_scale
end
write(joinpath(integrated_output,"input.json"),JSON3.write(human_input))
write(joinpath(frozen_root,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(human_roster))*"\n")
function patch_bridge(path,anchor,replacement)
    source=read(path,String);count(anchor,source)==1 || error("bridge anchor changed: $anchor")
    write(path,replace(source,anchor=>replacement))
end
const day_file=joinpath(frozen_root,"src/lw/simulation/day.jl")
if integrated_unlimited
    patch_bridge(day_file,"for sec in start_sec:days*div(clock.day_us,1_000_000)-1",
        "for sec in Main.integrated_ticks(start_sec,days,clock)")
    # STOP is checked AFTER the daily checkpoint; final reports use the actual day.
    checkpoint_line="            checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
    patch_bridge(day_file,checkpoint_line,checkpoint_line*"\n            if isfile(joinpath(Main.integrated_output,\"STOP\"))\n                days=length(daily)\n                break\n            end")
end
patch_bridge(day_file,"    wildlife=LWGrazing.build(spec,clock;low_obstacles)",
    "    wildlife=LWGrazing.build(spec,clock;low_obstacles)\n    predator_cohort=Main.integrated_predator_cohort(wildlife)")
patch_bridge(day_file,"LWGrazing.prepare!(wildlife,[w.positions[a] for a in IDS],sec;illumination=visual_illumination)",
    "Main.integrated_predator_prepare!(wildlife,predator_cohort,[w.positions[a] for a in IDS],sec,visual_illumination)")
patch_bridge(day_file,"LWGrazing.advance!(wildlife,sec)",
    "Main.integrated_predator_advance!(wildlife,predator_cohort,sec)")
patch_bridge(day_file,"wildlife_motion_samples=wildlife_motion_objects(wildlife,wildlife_previous_positions)",
    "wildlife_motion_samples=Main.integrated_predator_motion(wildlife_motion_objects(wildlife,wildlife_previous_positions),predator_cohort)")
patch_bridge(day_file,"daily[end][\"wildlife\"]=LWGrazing.snapshot(wildlife;",
    "daily[end][\"wildlife\"]=LWGrazing.snapshot(wildlife;additional_predation_deaths=Main.integrated_captures(predator_cohort),")
patch_bridge(day_file,"            checkpoint_dir!==nothing && checkpoint_save",
    "            Main.integrated_predator_daily!(daily[end],predator_cohort,length(daily),w)\n            checkpoint_dir!==nothing && checkpoint_save")
patch_bridge(joinpath(frozen_root,"src/lw/simulation/checkpoint.jl"),
    "incidental_items items relations trades foods wildlife mb_maps", "predator_cohort incidental_items items relations trades foods wildlife mb_maps")
# Save current state every requested interval, plus final/manual-stop boundaries.
patch_bridge(day_file,"checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)",
    "checkpoint_dir!==nothing && (mod(length(daily),Main.integrated_save_interval)==0 || length(daily)==days || isfile(joinpath(Main.integrated_output,\"STOP\"))) && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)")
# Load exactly one LW module so donor serialization and human world share types.
include(joinpath(frozen_root,"experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(frozen_root,"experiments/lw_wildlife/proximity_observer.jl"))
include(joinpath(frozen_root,"src/lw/configured_paths/rabbit_distributed_layout.jl"))
include(joinpath(frozen_root,"src/lw/configured_paths/predator_population_exchange.jl"))
include(joinpath(frozen_root,"src/lw/configured_paths/raptor_trial.jl"))
selected_donor>=0 || error("donor index")
const donor_record=selected_donor==0 ? nothing : deserialize(isfile(donor_directory) ? donor_directory : joinpath(donor_directory,"final.jls"))
const donor_cohort=donor_record!==nothing && hasproperty(donor_record,:state) ? donor_record.state[:predator_cohort] : nothing
const inherited_source=donor_cohort===nothing ? donor_record :
    (donor_record.state[:wildlife],donor_cohort.predators,donor_cohort.scents,donor_cohort.minds,
     donor_cohort.prey_scents,donor_cohort.local_hunts,donor_cohort.physiology)
const inherited_pursuits=donor_cohort!==nothing && hasproperty(donor_cohort,:pursuits) ? donor_cohort.pursuits : nothing
if inherited_source!==nothing
    1<=selected_donor<=length(inherited_source[2]) || error("donor index")
    inheritance_checks(inherited_source[4][selected_donor],inherited_source[6][selected_donor],inherited_source[1].ticks)
end
const bridge_started=time()
function integrated_predator_cohort(wildlife)
    if current_ecology
        configured_rabbit_distributed_layout!(wildlife)
        H.enable_grass_layers!(wildlife.world)
        P.configured_predator_terrain_enable!(wildlife.world;enabled=true)
        H.enable_rabbit_neighbor_batch!(wildlife.world;gpu=integrated_backend=="auto",audit=false,automatic=integrated_backend=="auto")
        @assert count(wildlife.alive)==integrated_ecology_setup.rabbits
    end
    predators=animal_trial_predators(wildlife)
    resize!(predators,integrated_predator_count)
    minds=PredatorMind[];locals=LocalHunt[]
    pursuits=PredatorPursuit.(eachindex(predators))
    for actor in eachindex(predators)
        mind,local_state=selected_donor==0 ? (PredatorMind(actor),LocalHunt(actor;probabilistic_capture=true)) :
            configured_predator_mb_inherit(inherited_source[4][selected_donor],inherited_source[6][selected_donor],actor,101,inherited_source[1].ticks)
        Random.seed!(predators[actor].visual.rng,20261106+1000*101+actor)
        current_ecology && (mind.estimates["crossing_enabled"]=1.)
        push!(minds,mind);push!(locals,local_state)
        if inherited_pursuits!==nothing
            configured_inherit_loop!(pursuits[actor].loop,inherited_pursuits[selected_donor].loop)
        end
    end
    if inherited_pursuits!==nothing
        @testset "independent inherited pursuit MBs" begin
            donor_loop=inherited_pursuits[selected_donor].loop
            for p in pursuits
                @test p.loop.sequence==donor_loop.sequence && Set(keys(p.loop.methods))==Set(keys(donor_loop.methods))
                @test p.loop.H==0 && p.loop.trial===nothing && p.active===nothing
                @test isempty(p.observed) && isempty(p.released) && isempty(p.records)
                for k in keys(donor_loop.methods)
                    @test p.loop.methods[k]!==donor_loop.methods[k]
                    @test p.loop.methods[k].reward==donor_loop.methods[k].reward && p.loop.methods[k].H==donor_loop.methods[k].H
                end
            end
            @test pursuits[1].loop.methods!==pursuits[2].loop.methods
            @test pursuits[1].loop.seed!=pursuits[2].loop.seed
        end
    end
    if selected_donor==0
        @testset "fresh predator MBs" begin
            for (mind,local_state) in zip(minds,locals)
                @test isempty(mind.loop.methods) && mind.loop.sequence==0 && mind.loop.H==0
                @test isempty(mind.places) && isempty(mind.acquisition)
                @test current_ecology ? mind.estimates==Dict("crossing_enabled"=>1.) : isempty(mind.estimates)
                @test isempty(mind.records) && mind.trial===nothing
                @test isempty(local_state.loop.methods) && local_state.loop.sequence==0
                @test isempty(local_state.memory) && isempty(local_state.capture_experience)
                @test local_state.probabilistic_capture
            end
            length(minds)<2 || @test minds[1]!==minds[2] && locals[1]!==locals[2]
        end
    end
    write(joinpath(integrated_output,"initial_predators.json"),JSON3.write((inherited=selected_donor!=0,
        predators=trial_predator_report.(predators),minds=predator_mind_report.(minds),
        local_methods=[length(s.loop.methods) for s in locals],capture_memories=[length(s.capture_experience) for s in locals],
        pursuits=pursuit_report.(pursuits))))
    (predators=predators,minds=minds,scents=PredatorScentWorld(length(predators)),prey_scents=PreyScentWorld(length(predators);cautious=true),
        local_hunts=locals,physiology=PredatorPhysiology.(predators),human_scent=human_scent_enabled ? HumanScentField(camp=human_input["scene"]["home"]) : nothing,
        proximity=proximity_observer(),pursuits=pursuits,world=wildlife,
        migration=current_ecology ? PredatorPopulationExchange(length(predators)) : nothing,
        raptor=current_ecology ? configured_raptor(wildlife,JSON3.read(JSON3.write(human_input["scene"]))) : nothing,
        rabbit_approach=current_ecology ? H.RabbitSwimmingPolicy(H.RabbitApproachPolicy()) : rabbit_approach_enabled ? G.H.RabbitApproachPolicy() : G.H.StateMachinePolicy())
end
function integrated_predator_prepare!(wildlife,c,humans,t,illumination)
    if current_ecology
        configured_predator_replacement_update!(wildlife,c,c.migration,t;crossing_enabled=true,target=integrated_predator_count)
        if t%RAPTOR_TRIAL.day_ticks==0
            was_present=c.raptor.present
            configured_raptor_population!(c.raptor,count(wildlife.alive),t)
            if !was_present && c.raptor.present
                c.raptor.visual.body.x,c.raptor.visual.body.z=configured_raptor_edge(wildlife.world,c.raptor.destination)
            elseif c.raptor.mode==:depart
                c.raptor.destination=configured_raptor_edge(wildlife.world,(c.raptor.visual.body.x,c.raptor.visual.body.z))
            end
        end
    end
    proximity_observe!(c.proximity,wildlife,c.predators,humans,human_input["scene"]["home"],t)
    c.human_scent===nothing || configured_human_scent_deposit!(c.human_scent,humans,t)
    animal_trial_prepare!(wildlife,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,
        motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,pursuits=c.pursuits,humans,illumination,raptor=c.raptor)
end
function integrated_predator_advance!(wildlife,c,t)
    animal_trial_advance!(wildlife,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=current_ecology ? integrated_ecology_setup.prey_nutrition : 1.5,
        prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,human_scent=c.human_scent,pursuits=c.pursuits,
        grazing_policy=c.rabbit_approach)
    c.raptor===nothing || configured_raptor_step!(c.raptor,wildlife,c.predators,t)
end
integrated_captures(c)=sum(p.visual.body.captures for p in c.predators)+(c.raptor===nothing ? 0 : c.raptor.captures)
function integrated_predator_motion(objects,c)
    for p in c.predators
        p.alive || continue
        b=p.visual.body;previous=p.visual.previous_position
        push!(objects,(actor="",x=b.x,z=b.z,vx=b.x-previous[1],vz=b.z-previous[2],
            height=G.WILDLIFE_PREDATOR.body_height,visibility=1.))
    end
    # Rabbit object vectors have a fixed NamedTuple type; rebuild with appearance here.
    rabbit_count=length(objects)-count(p->p.alive,c.predators)
    [merge(o,(appearance=i<=rabbit_count ? "small_furred_long_eared_body" : "medium_furred_pointed_snout_body",)) for (i,o) in enumerate(objects)]
end
function integrated_predator_daily!(day,c,number,w)
    day["raptor"]=c.raptor===nothing ? nothing : configured_raptor_report(c.raptor)
    day["predator_population"]=c.migration===nothing ? nothing : merge(configured_predator_population_report(c,c.migration,count(c.world.alive)),(target=integrated_predator_count,mode="replace"))
    day["learned_predators"]=(predators=trial_predator_report.(c.predators),physiology=predator_physiology_report.(c.physiology),minds=predator_mind_report.(c.minds))
    day["human_scent"]=human_scent_report(c.human_scent)
    day["predator_pursuits"]=pursuit_report.(c.pursuits)
    # Observer only; full H and private RNG remain in the serialized cohort.
    day["rabbit_approach"]=rabbit_approach_enabled ?
        Dict(string(i)=>(target=m.target,elapsed=m.elapsed,forecast=m.forecast,H=copy(m.H))
            for (i,m) in (current_ecology ? c.rabbit_approach.base : c.rabbit_approach).actors) : nothing
    day["wildlife_proximity"]=deepcopy(c.proximity)
    rabbits=day["wildlife"]
    @assert rabbits.count==rabbits.alive+rabbits.starvation_deaths+rabbits.predation_deaths
    @assert all(c.physiology[i].body.reserve==c.predators[i].food for i in eachindex(c.predators))
    row=(day=number,elapsed_seconds=time()-bridge_started,rabbits=rabbits.alive,rabbit_starvation=rabbits.starvation_deaths,
        predator_alive=[p.alive for p in c.predators],captures=[p.visual.body.captures for p in c.predators],
        humans=Dict(a=>w.bodies[a].reserve for a in human_roster),proximity=c.proximity,
        rabbit_west=count(i->c.world.alive[i] && c.world.animals.x[i]<12+5sin((c.world.animals.z[i]-6)/22+c.world.world.phase),eachindex(c.world.alive)),
        raptor=day["raptor"],predator_population=day["predator_population"])
    write(joinpath(integrated_output,"progress.json"),JSON3.write(row))
    open(joinpath(integrated_output,"daily.jsonl"),"a") do io;println(io,JSON3.write(row));end
    println("INTEGRATED_DAY ",JSON3.write(row));flush(stdout)
end
const bridge_conditions=(current_ecology,integrated_backend,checkpoint_interval_days=integrated_save_interval,ecology_setup=current_ecology ? integrated_ecology_setup : nothing,ecology_fixed=current_ecology ? "distributed initial layout; layered grass; selected neighbor backend; river cost; daily predator replacement; raptor arrival150/departure100" : nothing,days=requested_days,actors=human_roster,donor=selected_donor==0 ? nothing : donor_directory,donor_index=selected_donor,
    human_features=Dict(k=>get(human_input["scene"],k,nothing) for k in
        ("item_exchange","food_exchange","social_relationships","configured_negotiation","food_processing","game_proficiency","typed_food","food_batch_expiry","food_security_provision","incidental_items","item_attention","gradient_logging","configured_trade_idle","configured_trade_work_wait")),
    predator_mb_initialization=selected_donor==0 ? "fresh; no donor read; no inherited experience" : "inherited donor MB",
    pursuit_mb_inherited=inherited_pursuits!==nothing,
    rabbit_approach_enabled=rabbit_approach_enabled,rabbit_approach_parameters=G.H.RABBIT_APPROACH,
    direct_water_approach=PREDATOR_WATER_APPROACH,
    pursuit_decision=PREDATOR_PURSUIT,
    food_site_evidence=PREDATOR_FOOD_SITE,
    human_scent=human_scent_enabled,human_scent_rule=HUMAN_SCENT,fixed_camp_scent=human_scent_enabled ? human_input["scene"]["home"] : nothing,
    donor_captures=inherited_source===nothing ? nothing : inherited_source[2][selected_donor].visual.body.captures,wildlife=human_input["scene"]["wildlife"],
    human_input_origin=human_source_input,human_input_sha256=bytes2hex(sha256(read(human_source_input))),
    fixed="explicit predator initialization (see predator_mb_initialization); fresh bodies; reserve-demand target 900; previous human training and configured paths retained",
    interactions="rabbits react to humans and predators; humans observe both; no predator attack on humans or human hunting",
    checkpoint="predator cohort included in human daily serialization graph",stop=integrated_unlimited ? "manual STOP file at day boundary after checkpoint; no day/time limit; history retained" : "requested days, including after predator extinction")
write(joinpath(integrated_output,"conditions.json"),JSON3.write(bridge_conditions))
println("CONDITIONS ",JSON3.write(bridge_conditions));flush(stdout)
const native_file=joinpath(frozen_root,"integrations/lightweight_julia/native.jl")
native_source=read(native_file,String)
native_source=replace(native_source,"include(joinpath(@__DIR__, \"../../src/lw/simulation/integrated.jl\"))"=>"",
    "include(joinpath(@__DIR__, \"../../src/lw/world/generation.jl\"))"=>"")
write(native_file,native_source)
Base.include(LW,native_file)
LW.native_main([joinpath(integrated_output,"run"),"--spec",joinpath(integrated_output,"input.json"),
    "--checkpoint-dir",joinpath(integrated_output,"checkpoints")])
const final_result=JSON3.read(read(joinpath(integrated_output,"run/result.json"),String))
const integrated_completed_days=length(final_result.daily)
@test integrated_unlimited ? integrated_completed_days>0 && isfile(joinpath(integrated_output,"STOP")) : integrated_completed_days==requested_days
@test Set(keys(final_result.final_agents))==Set(Symbol.(human_roster))
const saved_day=deserialize(joinpath(integrated_output,"checkpoints","day-"*lpad(integrated_completed_days,3,'0')*".jls"))
@test haskey(saved_day.state,:predator_cohort)
@test (saved_day.state[:predator_cohort].rabbit_approach isa Union{G.H.RabbitApproachPolicy,G.H.RabbitSwimmingPolicy})==rabbit_approach_enabled
if rabbit_approach_enabled
    policy=saved_day.state[:predator_cohort].rabbit_approach
    @test !isempty((current_ecology ? policy.base : policy).actors)
end
@test integrated_captures(saved_day.state[:predator_cohort])==final_result.daily[end].wildlife.predation_deaths
write(joinpath(integrated_output,"completed.json"),JSON3.write((days=integrated_completed_days,verified=true,stop_reason=integrated_unlimited ? "manual_stop" : "duration")))
println("INTEGRATED_COMPLETE ",integrated_output)
