# Observer-only daily replay. No extra choices, random draws or scent-counter updates.
using JSON3, Serialization, Test
const audit_original=abspath(ARGS[1]);const audit_output=abspath(ARGS[2])
const audit_day=parse(Int,ARGS[3]);const audit_actor=parse(Int,ARGS[4])
const audit_config=JSON3.read(read(joinpath(audit_original,"conditions.json"),String))
empty!(ARGS);append!(ARGS,[String(audit_config.human_input_origin),String(audit_config.donor),audit_output,string(audit_day),string(audit_config.donor_index),string(audit_config.human_scent)])
const audit_bridge=joinpath(@__DIR__,"humans_learned_predators.jl")
const audit_prefix=first(split(read(audit_bridge,String),"LW.native_main([joinpath(integrated_output,\"run\")";limit=2))
include_string(Main,replace(audit_prefix,"function integrated_predator_advance!("=>"function audit_original_advance!("),audit_bridge)
const audit_counts=Dict{String,Int}()
const audit_path=Any[]
const audit_death=Ref{Any}(nothing)
const audit_distance=Ref(0.)
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
    audit_original_advance!(wildlife,c,t)
    if was_alive
        moved=b.distance-before_distance;audit_distance[]+=moved
        audit_count("stationary",moved<=1e-9)
        !p.alive && (audit_death[]=(tick=t,food_before=before_food,food_after=p.food,position=(b.x,b.z),mode=p.mode))
    end
end
const audit_resume=joinpath(audit_original,"checkpoints","day-"*lpad(audit_day-1,3,'0')*".jls")
const audit_saved=deserialize(audit_resume)
@test audit_saved.code==LW.checkpoint_code_hash()
LW.native_main([joinpath(integrated_output,"run"),"--spec",joinpath(integrated_output,"input.json"),"--checkpoint-dir",joinpath(integrated_output,"checkpoints"),"--resume-from",audit_resume])
const audit_result=JSON3.read(read(joinpath(audit_output,"run/result.json"),String))
const audit_expected=JSON3.read(read(joinpath(audit_original,"run/result.json"),String))
const audit_match=JSON3.read(JSON3.write(audit_result.daily[audit_day]),Dict{String,Any})==JSON3.read(JSON3.write(audit_expected.daily[audit_day]),Dict{String,Any})
@test audit_match
const audit_evidence=(day=audit_day,actor=audit_actor,exact_daily_match=audit_match,counts=audit_counts,
    distance=audit_distance[],death=audit_death[],path=audit_path,
    note="Nearest prey is world truth for diagnosis, not visibility. Samples before movement; path every 60 ticks. Scent signal is not proof of heading change.")
write(joinpath(audit_output,"audit.json"),JSON3.write(audit_evidence))
println("AUDIT_COMPLETE ",JSON3.write((day=audit_day,actor=audit_actor,exact_match=audit_match,counts=audit_counts,distance=audit_distance[],death=audit_death[])))
