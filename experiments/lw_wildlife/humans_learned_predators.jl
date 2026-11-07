# Experimental bridge only. Human policy stays unchanged; no attacks on humans.
# Usage: INPUT DONOR_GENERATION NEW_OUTPUT DAYS [DONOR_INDEX=2] [HUMAN_SCENT=false]
using JSON3, Serialization, SHA, Test
length(ARGS) in 4:6 || error("INPUT DONOR_GENERATION NEW_OUTPUT DAYS [DONOR_INDEX] [HUMAN_SCENT=false]")
const human_source_input=abspath(ARGS[1]);const donor_directory=abspath(ARGS[2])
const integrated_output=abspath(ARGS[3]);const requested_days=parse(Int,ARGS[4])
const selected_donor=length(ARGS)>=5 ? parse(Int,ARGS[5]) : 2
const human_scent_enabled=length(ARGS)>=6 ? parse(Bool,ARGS[6]) : false
1<=requested_days<=180 || error("days")
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
human_input["config"]["days"]=requested_days
const human_roster=String.(human_input["scene"]["experimental_actor_ids"])
@assert length(unique(human_roster))==length(human_roster)
@assert all(length(human_input["scene"][k])==length(human_roster) for k in ("positions","reserve","initial_inventory"))
# Provisional world setup and explicit learned-MB copying, not natural reproduction.
human_input["scene"]["wildlife"]=merge(human_input["scene"]["wildlife"],
    Dict("enabled"=>true,"count"=>95,"predator_count"=>0,"grass_scale"=>3.,"boundary_gradient"=>true))
write(joinpath(integrated_output,"input.json"),JSON3.write(human_input))
write(joinpath(frozen_root,"src/data/lw_actor_ids.jl"),"const IDS="*repr(Tuple(human_roster))*"\n")
function patch_bridge(path,anchor,replacement)
    source=read(path,String);count(anchor,source)==1 || error("bridge anchor changed: $anchor")
    write(path,replace(source,anchor=>replacement))
end
const day_file=joinpath(frozen_root,"src/lw/simulation/day.jl")
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
# Load exactly one LW module so donor serialization and human world share types.
include(joinpath(frozen_root,"experiments/lw_wildlife/predator_generations.jl"))
include(joinpath(frozen_root,"experiments/lw_wildlife/proximity_observer.jl"))
const inherited_source=deserialize(joinpath(donor_directory,"final.jls"))
1<=selected_donor<=length(inherited_source[2]) || error("donor index")
inheritance_checks(inherited_source[4][selected_donor],inherited_source[6][selected_donor],inherited_source[1].ticks)
const bridge_started=time()
function integrated_predator_cohort(wildlife)
    predators=animal_trial_predators(wildlife)
    minds=PredatorMind[];locals=LocalHunt[]
    for actor in 1:2
        mind,local_state=configured_predator_mb_inherit(inherited_source[4][selected_donor],inherited_source[6][selected_donor],actor,101,inherited_source[1].ticks)
        Random.seed!(predators[actor].visual.rng,20261106+1000*101+actor)
        push!(minds,mind);push!(locals,local_state)
    end
    (predators=predators,minds=minds,scents=PredatorScentWorld(2),prey_scents=PreyScentWorld(2;cautious=true),
        local_hunts=locals,physiology=PredatorPhysiology.(predators),human_scent=human_scent_enabled ? HumanScentField(camp=human_input["scene"]["home"]) : nothing,
        proximity=proximity_observer())
end
function integrated_predator_prepare!(wildlife,c,humans,t,illumination)
    proximity_observe!(c.proximity,wildlife,c.predators,humans,human_input["scene"]["home"],t)
    c.human_scent===nothing || configured_human_scent_deposit!(c.human_scent,humans,t)
    animal_trial_prepare!(wildlife,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,
        motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,humans,illumination)
end
function integrated_predator_advance!(wildlife,c,t)
    animal_trial_advance!(wildlife,c.predators,t;scents=c.scents,minds=c.minds,prey_nutrition=1.5,
        prey_scents=c.prey_scents,local_hunts=c.local_hunts,physiology=c.physiology,human_scent=c.human_scent)
end
integrated_captures(c)=sum(p.visual.body.captures for p in c.predators)
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
    day["learned_predators"]=(predators=trial_predator_report.(c.predators),physiology=predator_physiology_report.(c.physiology),minds=predator_mind_report.(c.minds))
    day["human_scent"]=human_scent_report(c.human_scent)
    day["wildlife_proximity"]=deepcopy(c.proximity)
    rabbits=day["wildlife"]
    @assert rabbits.count==rabbits.alive+rabbits.starvation_deaths+rabbits.predation_deaths
    @assert all(c.physiology[i].body.reserve==c.predators[i].food for i in eachindex(c.predators))
    row=(day=number,elapsed_seconds=time()-bridge_started,rabbits=rabbits.alive,rabbit_starvation=rabbits.starvation_deaths,
        predator_alive=[p.alive for p in c.predators],captures=[p.visual.body.captures for p in c.predators],
        humans=Dict(a=>w.bodies[a].reserve for a in human_roster),proximity=c.proximity)
    write(joinpath(integrated_output,"progress.json"),JSON3.write(row))
    open(joinpath(integrated_output,"daily.jsonl"),"a") do io;println(io,JSON3.write(row));end
    println("INTEGRATED_DAY ",JSON3.write(row));flush(stdout)
end
const bridge_conditions=(days=requested_days,actors=human_roster,donor=donor_directory,donor_index=selected_donor,
    human_scent=human_scent_enabled,human_scent_rule=HUMAN_SCENT,fixed_camp_scent=human_scent_enabled ? human_input["scene"]["home"] : nothing,
    donor_captures=inherited_source[2][selected_donor].visual.body.captures,wildlife=human_input["scene"]["wildlife"],
    human_input_origin=human_source_input,human_input_sha256=bytes2hex(sha256(read(human_source_input))),
    fixed="explicit B MB copies; fresh bodies; reserve-demand target 900; previous human training and configured paths retained",
    interactions="rabbits react to humans and predators; humans observe both; no predator attack on humans or human hunting",
    checkpoint="predator cohort included in human daily serialization graph",stop="requested days, including after predator extinction")
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
@test length(final_result.daily)==requested_days
@test Set(keys(final_result.final_agents))==Set(Symbol.(human_roster))
const saved_day=deserialize(joinpath(integrated_output,"checkpoints","day-"*lpad(requested_days,3,'0')*".jls"))
@test haskey(saved_day.state,:predator_cohort)
@test integrated_captures(saved_day.state[:predator_cohort])==final_result.daily[end].wildlife.predation_deaths
write(joinpath(integrated_output,"completed.json"),JSON3.write((days=requested_days,verified=true)))
println("INTEGRATED_COMPLETE ",integrated_output)
