# Guarded one-time relocation. Existing CLI bodies remain in compatibility entries.
root=normpath(joinpath(@__DIR__,".."))
legacy=joinpath(root,"experiments/julia_migration")
mapping=Dict{String,String}()
function register(old,new)
    mapping[normpath(joinpath(legacy,old))]=normpath(joinpath(root,new))
end
groups=Dict(
 "world"=>["world_hazards","ground","landscape","ground_wear","dropped_cargo"],
 "perception"=>["hazard","orientation","skyline","ground_pattern","ground_continuity"],
 "decision"=>["reposition","climbing","return_purpose","social_response","food_body","basic_loop","approach","local_descent","repetition_pressure","safety_methods","movement_inertia","exploration_horizon","relation_field","lateral_bias"],
 "learning"=>["experience_bundles","selection_trail","general_sleep","sleep_action_model","sleep_maintenance","landmark_routes","harvest_learning","harvest_field","harvest_review","harvest_relearn"])
for (layer,names) in groups, name in names
    register("lw_day/$name.jl","src/lw/$layer/$name.jl")
end
for (old,new) in (
    "all_loop/loop.jl"=>"src/lw/simulation/legacy_loop.jl",
    "social_loop/run.jl"=>"src/lw/simulation/social.jl",
    "moving_social/run.jl"=>"src/lw/simulation/moving.jl",
    "incremental_aid/state.jl"=>"src/lw/learning/aid.jl",
    "lw_day/run.jl"=>"src/lw/simulation/day.jl",
    "lw_integrated/run.jl"=>"src/lw/simulation/integrated.jl",
    "lw_integrated/world.jl"=>"src/lw/world/generation.jl",
    "lw_integrated/native.jl"=>"integrations/lightweight_julia/native.jl")
    register(old,new)
end
aliases=Dict(
 normpath(joinpath(legacy,"social_loop/models.jl"))=>joinpath(root,"src/lw/learning/social_models.jl"),
 normpath(joinpath(legacy,"julia/src/RDLMigrationProbe.jl"))=>joinpath(root,"src/geometry/RDLMigrationProbe.jl"),
 normpath(joinpath(legacy,"lw_day/digestion.jl"))=>joinpath(root,"src/body/load.jl"))
pattern=r"include\(joinpath\(@__DIR__,\s*\"([^\"]+)\"\)\)"
prepared=[]
for (old,new) in mapping
    isfile(new) && error("Destination already exists: $new")
    text=replace(read(old,String),"\r\n"=>"\n")
    guard=findfirst(r"(?m)^if abspath\(PROGRAM_FILE\)\s*==\s*@__FILE__",text)
    cli=guard===nothing ? "" : text[first(guard):end]
    core=guard===nothing ? text : text[1:prevind(text,first(guard))]
    core=replace(core,pattern=>s->begin
        m=match(pattern,s)
        target=normpath(joinpath(dirname(old),m.captures[1]))
        target=get(mapping,target,get(aliases,target,target))
        startswith(target,legacy) && error("Unmigrated dependency: $target")
        "include(joinpath(@__DIR__, \""*replace(relpath(target,dirname(new)),'\\'=>'/')*"\"))"
    end)
    push!(prepared,(old,new,core,cli))
end
for (old,new,core,cli) in prepared
    mkpath(dirname(new));write(new,core)
    path=replace(relpath(new,dirname(old)),'\\'=>'/')
    write(old,"# Compatibility entry; canonical implementation is in src or integrations.\ninclude(joinpath(@__DIR__, \"$path\"))\n"*cli)
end
println("Relocated $(length(prepared)) LW implementation files")
