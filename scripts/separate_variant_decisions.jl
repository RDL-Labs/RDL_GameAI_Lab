root=normpath(joinpath(@__DIR__,".."))
for variant in ("predator-cpu","motion-vision-cpu")
    path=joinpath(root,"src/ecology",variant,"Herbivores.jl")
    text=replace(read(path,String),"\r\n"=>"\n")
    a=first(something(findfirst("function choose_state",text)))
    b=first(something(findfirst("function step!",text)))
    replacement="""
include("../herbivore/perception.jl")
include("../herbivore/decision.jl")
function target!(w,a,i,t,policy=StateMachinePolicy())
    a.target[i]=choose_target(policy,observe_neighbors!(w,a,i,t),a.heading[i],a.previous_cell[i])
    a.next_sense[i]=t+10
end
"""
    text=replace(text,text[a:prevind(text,b)]=>replacement)
    text=replace(text,"; threat=nothing, alive=nothing"=>"; policy=StateMachinePolicy(), threat=nothing, alive=nothing")
    old="""
        k=cell(w,a.x[i],a.z[i]); localgrass=grass!(w,k,t)
        danger=threat!==nothing && hypot(a.x[i]-threat[1],a.z[i]-threat[2])<10 && clear(w,(a.x[i],a.z[i]),threat)
        a.state[i]=choose_state(a.state[i],a.energy[i],a.gut[i],a.sleepy[i],localgrass,danger)
"""
    occursin(old,text) || error("Missing herbivore observation")
    text=replace(text,old=>"        observation=observe_state!(w,a,i,t,threat);k=observation.cell\n        a.state[i]=choose_state(policy,observation)\n")
    text=replace(text,"&& target!(w,a,i,t)"=>"&& target!(w,a,i,t,policy)")
    write(path,text)
end
for variant in ("predator-cpu","motion-vision-cpu","directional-vision-cpu")
    path=joinpath(root,"src/ecology",variant,"Predators.jl")
    text=replace(read(path,String),"\r\n"=>"\n")
    a=first(something(findfirst("function plan!",text)))
    b=first(something(findfirst("function advance!",text)))
    original=text[a:prevind(text,b)]
    header=first(split(original,'\n'))
    observe_header=replace(header,"plan!(w,p,a,alive,t,rng"=>"observe_prey(w,p,a,alive,t")
    clause=variant=="predator-cpu" ? "" : variant=="motion-vision-cpu" ? ";motion,moved=moved===nothing ? true : moved[i]" : ";motion,moved=moved===nothing ? true : moved[i],gaze"
    kwargs=variant=="predator-cpu" ? "" : variant=="motion-vision-cpu" ? ";motion,moved" : ";motion,moved,gaze"
    observe=observe_header*"\n    observations=NamedTuple{(:id,:x,:z,:distance),Tuple{Int,Float64,Float64,Float64}}[]\n    for i in eachindex(alive)\n        alive[i] && visible(w,p,a,i,t$clause) || continue\n        push!(observations,(id=i,x=a.x[i],z=a.z[i],distance=hypot(a.x[i]-p.x,a.z[i]-p.z)))\n    end\n    observations\nend\n"
    decision=replace(original,header=>"function decide!(p,observations,t,rng)")
    loop_start=first(something(findfirst("        best=0; dmin=Inf",decision)))
    loop_end=first(something(findfirst("        if best!=0",decision)))
    decision=replace(decision,decision[loop_start:prevind(decision,loop_end)]=>"        best=0;dmin=Inf;seen=nothing\n        for o in observations\n            if o.distance<dmin;best=o.id;dmin=o.distance;seen=o;end\n        end\n")
    decision=replace(decision,"p.seen_x=a.x[best]; p.seen_z=a.z[best]"=>"p.seen_x=seen.x; p.seen_z=seen.z")
    wrapper=header*"\n    observations=p.state in (REST,RECOVER,ATTACK) ? nothing : observe_prey(w,p,a,alive,t$kwargs)\n    decide!(p,observations,t,rng)\nend\n"
    write(joinpath(dirname(path),"perception.jl"),observe)
    write(joinpath(dirname(path),"decision.jl"),decision)
    write(path,replace(text,original=>"include(\"perception.jl\")\ninclude(\"decision.jl\")\n"*wrapper))
end
