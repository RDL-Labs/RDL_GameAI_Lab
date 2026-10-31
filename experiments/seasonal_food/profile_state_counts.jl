using JSON3, Serialization
length(ARGS)==2 || error("usage: profile_state_counts.jl RUN OUTPUT.json")
run=abspath(ARGS[1])
include(joinpath(run,"source/integrations/lightweight_julia/native.jl"))
rows=Any[]
for day in (29,173)
    GC.gc()
    c=deserialize(joinpath(run,"checkpoints","day-"*lpad(day,3,'0')*".jls"))
    s=c.state
    loops=Dict(a=>Dict(f=>Dict("total"=>length(l.methods),"ground"=>count(k->startswith(k,"ground_"),keys(l.methods))) for (f,l) in families) for (a,families) in s[:loops])
    maps=Dict(a=>Dict(k=>length(get(m,k,Dict())) for k in ("nodes","edges","chunks")) for (a,m) in s[:mb_maps])
    social=Dict(a=>Dict(k=>length(get(r["mb"],k,Dict())) for k in ("nodes","pending")) for (a,r) in s[:relations])
    exchanges=Dict(a=>length(get(v,"exchange_relations",Any[])) for (a,v) in s[:incidental_items])
    push!(rows,(day=day,daily_history=length(s[:daily]),loop_methods=loops,mb_maps=maps,social_mb=social,exchange_relations=exchanges))
    c=nothing;s=nothing
end
write(ARGS[2],JSON3.write(rows));println(JSON3.write(rows))
