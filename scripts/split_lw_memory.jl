root=normpath(joinpath(@__DIR__,".."))
mkpath(joinpath(root,"src/data"))
path=joinpath(root,"src/lw/learning/social_models.jl")
text=replace(read(path,String),"\r\n"=>"\n")
anchors=["# A1 GameAI-local", "function ginitial", "function select_target", "social_initial()", "const DAY="]
starts=[first(something(findfirst(a,text))) for a in anchors]
destinations=["src/data/lw_model_types.jl","src/lw/learning/goal_updates.jl","src/lw/decision/social_target.jl","src/lw/learning/social_memory.jl","src/lw/learning/sleep_cycle.jl"]
for i in eachindex(starts)
    stop=i==length(starts) ? lastindex(text) : prevind(text,starts[i+1])
    write(joinpath(root,destinations[i]),text[starts[i]:stop])
end
write(path,join(["include(\""*replace(relpath(joinpath(root,d),dirname(path)),'\\'=>'/')*"\")\n" for d in destinations]))
path=joinpath(root,"src/lw/simulation/social.jl")
text=read(path,String)
ids="const IDS=(\"npc_a\",\"npc_b\",\"npc_c\")"
occursin(ids,text) || error("Missing actor table")
write(joinpath(root,"src/data/lw_actor_ids.jl"),"# Stable actor labels for the existing three-agent LW scenario contract.\n"*ids*"\n")
write(path,replace(text,ids=>"include(\"../../data/lw_actor_ids.jl\")"))
path=joinpath(root,"src/lw/simulation/legacy_loop.jl")
text=replace(read(path,String),"\r\n"=>"\n")
a=first(something(findfirst("mutable struct Agent",text)))
b=first(something(findfirst("bodydict(b)",text)))
body=text[a:prevind(text,b)]
write(joinpath(root,"src/data/lw_agent.jl"),body)
write(path,replace(text,body=>"include(\"../../data/lw_agent.jl\")\n"))
