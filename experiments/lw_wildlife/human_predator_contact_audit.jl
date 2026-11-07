# Observer-only replay of day 17 from the integrated day-16 checkpoint.
using JSON3, Serialization, Test
const contact_original=abspath(ARGS[1]);const contact_output=abspath(ARGS[2])
const contact_day=length(ARGS)>2 ? parse(Int,ARGS[3]) : 17
const contact_config=JSON3.read(read(joinpath(contact_original,"conditions.json"),String))
empty!(ARGS);append!(ARGS,[String(contact_config.human_input_origin),String(contact_config.donor),contact_output,string(contact_day),string(contact_config.donor_index)])
const bridge_path=joinpath(@__DIR__,"humans_learned_predators.jl")
const bridge_prefix=first(split(read(bridge_path,String),"LW.native_main([joinpath(integrated_output,\"run\")";limit=2))
include_string(Main,bridge_prefix,bridge_path)
const contact_rows=Dict{Tuple{String,Int},Any}()
const contact_tick=Ref(0)
const contact_positions=Ref(Tuple{Float64,Float64}[])
const contact_views=Any[]
function integrated_predator_prepare!(wildlife,c,humans,t,illumination)
    contact_tick[]=t;contact_positions[]=copy(humans)
    for (i,human) in enumerate(humans), (j,p) in enumerate(c.predators)
        p.alive || continue
        b=p.visual.body;distance=hypot(human[1]-b.x,human[2]-b.z)
        row=get!(()->Dict{String,Any}("human"=>human_roster[i],"predator"=>j,"minimum"=>Inf,
            "minimum_tick"=>0,"within_8_ticks"=>0,"within_3_ticks"=>0,"within_1_ticks"=>0),contact_rows,(human_roster[i],j))
        if distance<row["minimum"]
            row["minimum"]=distance;row["minimum_tick"]=t;row["human_position"]=human;row["predator_position"]=(b.x,b.z)
        end
        # Diagnostic distance bands only; never affect choice or physical contact.
        row["within_8_ticks"]+=distance<=8
        row["within_3_ticks"]+=distance<=3
        row["within_1_ticks"]+=distance<=1
    end
    animal_trial_prepare!(wildlife,c.predators,t;scents=c.scents,minds=c.minds,prey_scents=c.prey_scents,
        motion_speed=true,local_hunts=c.local_hunts,physiology=c.physiology,humans,illumination)
end
function contact_record_view(position,view)
    predators=filter(f->get(f,"appearance","")=="medium_furred_pointed_snout_body",view)
    if !isempty(predators)
        actors=[human_roster[i] for (i,p) in enumerate(contact_positions[]) if p==position]
        push!(contact_views,(tick=contact_tick[],actors=actors,features=deepcopy(predators)))
    end
    view
end
const view_source=read(joinpath(frozen_root,"src/lw/perception/wildlife.jl"),String)
const view_function="function wildlife_view"*split(view_source,"function wildlife_view";limit=2)[2]
Base.include_string(LW,replace(view_function,"function wildlife_view("=>"function contact_original_view("),"contact_original_view.jl")
@eval LW function wildlife_view(position,yaw,objects;occluders=(),illumination=1.)
    Main.contact_record_view(position,contact_original_view(position,yaw,objects;occluders,illumination))
end
const resume_file=joinpath(contact_original,"checkpoints","day-"*lpad(contact_day-1,3,'0')*".jls")
const saved_contact=deserialize(resume_file)
@test saved_contact.code==LW.checkpoint_code_hash()
LW.native_main([joinpath(integrated_output,"run"),"--spec",joinpath(integrated_output,"input.json"),
    "--checkpoint-dir",joinpath(integrated_output,"checkpoints"),"--resume-from",resume_file])
const replay_result=JSON3.read(read(joinpath(integrated_output,"run/result.json"),String))
const original_result=JSON3.read(read(joinpath(contact_original,"run/result.json"),String))
const matched_day=JSON3.read(JSON3.write(replay_result.daily[contact_day]),Dict{String,Any})==
    JSON3.read(JSON3.write(original_result.daily[contact_day]),Dict{String,Any})
@test matched_day
const contact_evidence=(day=contact_day,daily_result_exact_match=matched_day,
    distance_sampling="before movement, every tick; diagnostic bands are not physical collision tests",
    distances=[contact_rows[k] for k in sort(collect(keys(contact_rows)))],
    actual_predator_view_calls=length(contact_views),views=contact_views)
write(joinpath(contact_output,"contact.json"),JSON3.write(contact_evidence))
println("CONTACT_COMPLETE ",JSON3.write((day=contact_day,exact_match=matched_day,views=length(contact_views),
    distances=contact_evidence.distances)))
