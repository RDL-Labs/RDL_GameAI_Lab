using JSON3
root=ARGS[1]
rows=JSON3.read(read(joinpath(root,"trace.json"),String),Vector{Dict{String,Any}})
context=JSON3.read(read(joinpath(root,"context.json"),String),Dict{String,Any})
house=only(filter(h->h["owner"]=="npc_d",context["houses"]))
distance(p)=hypot(p[1]-house["x"],p[2]-house["z"])
travel=filter(r->r["method"]=="personal_house_return",rows)
stationary=filter(r->hypot((r["after"].-r["before"])...)<1e-12,travel)
boundary=filter(r->abs(distance(r["before"])-house["radius"]*.8)<1e-12,stationary)
groups=Any[]
for r in stationary
    if isempty(groups) || r["us"]!=groups[end]["last_us"]+1_000_000 || r["before"]!=groups[end]["position"]
        push!(groups,Dict("first_us"=>r["us"],"last_us"=>r["us"],"position"=>r["before"],
            "distance"=>distance(r["before"]),"ticks"=>1,"first"=>r,"last"=>r))
    else
        groups[end]["ticks"]+=1;groups[end]["last_us"]=r["us"];groups[end]["last"]=r
    end
end
sort!(groups;by=g->-g["ticks"])
counts=Dict(k=>count(r->r["status"]==k,travel) for k in unique(r["status"] for r in travel))
out=Dict("house"=>house,"travel_actions"=>length(travel),"stationary"=>length(stationary),
    "boundary_stationary"=>length(boundary),"status_counts"=>counts,"longest_stalls"=>first(groups,min(5,length(groups))),
    "house_state"=>context["house_state"],"parity"=>context["parity"])
write(joinpath(root,"analysis.json"),JSON3.write(out))
println(JSON3.write(out))
