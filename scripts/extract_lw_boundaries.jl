root=normpath(joinpath(@__DIR__,".."))
legacy=joinpath(root,"experiments/julia_migration")
source=joinpath(root,"src/lw")
for layer in ("world","perception","learning")
    mkpath(joinpath(source,layer))
end
function extract!(path,start,stop,destination,entry)
    text=replace(read(path,String),"\r\n"=>"\n")
    a=findfirst(start,text); b=findfirst(stop,text)
    a===nothing || b===nothing ? error("Already extracted or source changed: $path") : nothing
    body=text[first(a):prevind(text,first(b))]
    write(destination,body)
    write(path,replace(text,body=>entry*"\n\n"))
end
moving=joinpath(legacy,"moving_social/run.jl")
social=joinpath(legacy,"social_loop/run.jl")
extract!(moving,"function moving_world","function movement_observation",
    joinpath(source,"world/moving_world.jl"),
    "include(joinpath(@__DIR__, \"../../../src/lw/world/moving_world.jl\"))")
extract!(moving,"function movement_observation","function moving_scenario",
    joinpath(source,"perception/movement.jl"),
    "include(joinpath(@__DIR__, \"../../../src/lw/perception/movement.jl\"))")
extract!(social,"mutable struct ContactWorld","function observe",
    joinpath(source,"world/contact.jl"),
    "include(joinpath(@__DIR__, \"../../../src/lw/world/contact.jl\"))")
extract!(social,"function observe","function communicate!",
    joinpath(source,"perception/social.jl"),
    "include(joinpath(@__DIR__, \"../../../src/lw/perception/social.jl\"))")
models=joinpath(legacy,"social_loop/models.jl")
text=read(models,String)
occursin("mutable struct Records",text) || error("Models already extracted")
write(joinpath(source,"learning/social_models.jl"),text)
write(models,"# Compatibility entry for social memory and decision models.\ninclude(joinpath(@__DIR__, \"../../../src/lw/learning/social_models.jl\"))\n")
