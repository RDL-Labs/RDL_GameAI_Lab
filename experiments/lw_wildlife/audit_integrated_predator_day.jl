# Observer-only daily replay. No extra choices, random draws or scent-counter updates.
using JSON3, Serialization, Test
const audit_original=abspath(ARGS[1]);const audit_output=abspath(ARGS[2])
const audit_day=parse(Int,ARGS[3]);const audit_actor=parse(Int,ARGS[4])
const audit_pursuit_variant=length(ARGS)>=5 && ARGS[5]=="pursuit"
const audit_water_variant=length(ARGS)>=5 && ARGS[5] in ("water-approach","pursuit")
const audit_config=JSON3.read(read(joinpath(audit_original,"conditions.json"),String))
empty!(ARGS);append!(ARGS,[String(audit_config.human_input_origin),String(audit_config.donor),audit_output,string(audit_day),string(audit_config.donor_index),string(audit_config.human_scent)])
const audit_bridge=joinpath(@__DIR__,"humans_learned_predators.jl")
const audit_prefix=first(split(read(audit_bridge,String),"LW.native_main([joinpath(integrated_output,\"run\")";limit=2))
include_string(Main,replace(audit_prefix,"function integrated_predator_advance!("=>"function audit_original_advance!("),audit_bridge)
const audit_counts=Dict{String,Int}()
const audit_path=Any[]
const audit_death=Ref{Any}(nothing)
const audit_distance=Ref(0.)
const audit_movement=Any[]
const audit_context=Ref{Any}(nothing)
# Wrap the frozen movement function in memory; keep every original operation/RNG call.
const audit_move_file=joinpath(frozen_root,"src/ecology/directional-vision-cpu/Predators.jl")
const audit_move_source=read(audit_move_file,String)
const audit_move_start=findfirst("function move!",audit_move_source).start
const audit_move_end=findnext("include(\"perception.jl\")",audit_move_source,audit_move_start).start
Base.include_string(P,replace(audit_move_source[audit_move_start:prevind(audit_move_source,audit_move_end)],
    "function move!("=>"function audit_original_move!("),"audit_original_move")
@eval P function move!(w,p,speed;turn=true)
    context=Main.audit_context[]
    tracked=context!==nothing && p===context.body && p.state==CHASE && p.target!=0
    before=tracked ? (p.x,p.z,p.heading,p.target,p.blocked) : nothing
    result=audit_original_move!(w,p,speed;turn)
    tracked && Main.audit_record_move(w,p,speed,before,result,context)
    result
end
function audit_record_move(w,b,speed,before,result,context)
    x,z,heading,target,blocked=before;a=context.world.animals
    origin=(x,z);h=H.configured_boundary_heading(w,origin,heading)
    q=(x+speed*cos(h),z+speed*sin(h))
    boundary=!(w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25)
    water=H.material(w.phase,q...)==H.WATER || H.material(w.phase,(x+q[1])/2,(z+q[2])/2)==H.WATER
    obstacles=findall(o->H.RDLMigrationProbe.segment_hit(origin,q,o,.25),w.obstacles)
    prey=(a.x[target],a.z[target]);oldprey=context.prey_positions[target]
    push!(audit_movement,(tick=context.tick,target=target,origin=origin,position=(b.x,b.z),
        prey_before=oldprey,prey_after=prey,prey_state=a.state[target],prey_alive=context.world.alive[target],
        requested_speed=speed,moved=hypot(b.x-x,b.z-z),prey_moved=hypot(prey[1]-oldprey[1],prey[2]-oldprey[2]),
        distance_before=hypot(oldprey[1]-x,oldprey[2]-z),distance_after=hypot(prey[1]-b.x,prey[2]-b.z),
        first_clear=H.clear(w,origin,q),boundary=boundary,water=water,obstacles=obstacles,
        move_success=result,blocked_delta=b.blocked-blocked,los=P.los(w,origin,prey),
        boundary_turn=abs(P.angle_delta(h-heading)),actual_turn=abs(P.angle_delta(b.heading-h))))
end
audit_count(key,yes=true)=yes && (audit_counts[key]=get(audit_counts,key,0)+1)
function integrated_predator_advance!(wildlife,c,t)
    p=c.predators[audit_actor];b=p.visual.body;was_alive=p.alive
    before_position=(b.x,b.z);before_food=p.food;before_distance=b.distance
    if was_alive
        g=human_scent_gradient(c.human_scent,b.x,b.z,t)
        near=minimum((hypot(wildlife.animals.x[i]-b.x,wildlife.animals.z[i]-b.z) for i in eachindex(wildlife.alive) if wildlife.alive[i]);init=Inf)
        audit_count("alive");audit_count("mode:"*string(p.mode))
        audit_count("visual_state:"*string(b.state))
        audit_count("camp_signal",g.camp_signal>0);audit_count("trail_signal",g.trail_signal>0)
        audit_count("tracked_target",b.target!=0 && t<b.expires)
        audit_count("prey_world_within6",near<=6);audit_count("prey_world_within16",near<=16)
        if t%60==0
            push!(audit_path,(tick=t,position=before_position,food=before_food,mode=p.mode,state=b.state,
                target=b.target,target_valid=t<b.expires,nearest_world_prey=near,camp_signal=g.camp_signal,
                trail_signal=g.trail_signal,strain=c.physiology[audit_actor].body.strain,
                selected=c.minds[audit_actor].selected))
            # Freeze mutable choice data so later updates cannot rewrite observer history.
            audit_path[end]=deepcopy(audit_path[end])
        end
    end
    audit_context[]=(body=b,world=wildlife,tick=t,prey_positions=collect(zip(wildlife.animals.x,wildlife.animals.z)))
    audit_original_advance!(wildlife,c,t)
    audit_context[]=nothing
    if was_alive
        moved=b.distance-before_distance;audit_distance[]+=moved
        audit_count("stationary",moved<=1e-9)
        !p.alive && (audit_death[]=(tick=t,food_before=before_food,food_after=p.food,position=(b.x,b.z),mode=p.mode))
    end
end
const audit_resume=joinpath(audit_original,"checkpoints","day-"*lpad(audit_day-1,3,'0')*".jls")
const audit_saved=deserialize(audit_resume)
const audit_resume_effective=if audit_water_variant
    oldroot=joinpath(audit_original,"source/src");newroot=joinpath(frozen_root,"src")
    paths(root)=Set(relpath(joinpath(d,f),root) for (d,_,fs) in walkdir(root) for f in fs if endswith(f,".jl"))
    changed=sort([p for p in union(paths(oldroot),paths(newroot)) if
        !isfile(joinpath(oldroot,p)) || !isfile(joinpath(newroot,p)) || read(joinpath(oldroot,p))!=read(joinpath(newroot,p))])
    allowed=["lw/configured_paths/predator_local_hunt.jl","lw/configured_paths/predator_water_approach.jl"]
    audit_pursuit_variant && push!(allowed,"lw/configured_paths/predator_pursuit.jl")
    @test Set(replace.(changed,'\\'=>'/'))==Set(allowed)
    # Explicit experiment-only metadata migration; saved state/RNG/identity unchanged.
    migrated=joinpath(audit_output,"variant-start.jls")
    migrated_state=copy(audit_saved.state)
    if audit_pursuit_variant
        migrated_state[:predator_cohort]=merge(migrated_state[:predator_cohort],(pursuits=PredatorPursuit.(1:2),))
    end
    serialize(migrated,merge(audit_saved,(code=LW.checkpoint_code_hash(),state=migrated_state)))
    write(joinpath(audit_output,"migration.json"),JSON3.write((original=audit_resume,old_code=audit_saved.code,new_code=LW.checkpoint_code_hash(),changed_files=changed,state=audit_pursuit_variant ? "all old state/RNG preserved; add empty pursuit sidecars" : "unchanged; metadata code only")))
    migrated
else
    @test audit_saved.code==LW.checkpoint_code_hash()
    audit_resume
end
LW.native_main([joinpath(integrated_output,"run"),"--spec",joinpath(integrated_output,"input.json"),"--checkpoint-dir",joinpath(integrated_output,"checkpoints"),"--resume-from",audit_resume_effective])
const audit_result=JSON3.read(read(joinpath(audit_output,"run/result.json"),String))
const audit_expected=JSON3.read(read(joinpath(audit_original,"run/result.json"),String))
const audit_match=JSON3.read(JSON3.write(audit_result.daily[audit_day]),Dict{String,Any})==JSON3.read(JSON3.write(audit_expected.daily[audit_day]),Dict{String,Any})
audit_water_variant || @test audit_match
const audit_evidence=(day=audit_day,actor=audit_actor,exact_daily_match=audit_match,counts=audit_counts,
    distance=audit_distance[],death=audit_death[],path=audit_path,
    note="Nearest prey is world truth for diagnosis, not visibility. Samples before movement; path every 60 ticks. Scent signal is not proof of heading change.")
write(joinpath(audit_output,"audit.json"),JSON3.write(audit_evidence))
write(joinpath(audit_output,"movement.json"),JSON3.write(audit_movement))
if audit_water_variant
    ending=deserialize(joinpath(audit_output,"checkpoints","day-"*lpad(audit_day,3,'0')*".jls"))
    write(joinpath(audit_output,"variant.json"),JSON3.write((mode=audit_pursuit_variant ? "pursuit" : "water-approach",day=audit_day,
        pursuits=audit_pursuit_variant ? pursuit_report.(ending.state[:predator_cohort].pursuits) : nothing,
        predators=audit_result.daily[audit_day].learned_predators.predators,
        local_counts=[local_state.counts for local_state in ending.state[:predator_cohort].local_hunts])))
end
println("AUDIT_COMPLETE ",JSON3.write((day=audit_day,actor=audit_actor,exact_match=audit_match,counts=audit_counts,distance=audit_distance[],death=audit_death[])))
