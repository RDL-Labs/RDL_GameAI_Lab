using JSON3
r=JSON3.read(read(joinpath(ARGS[1],"run/result.json"),String))
for a in keys(r.mb_map)
 m=r.mb_map[a]
 println(JSON3.write(Dict("actor"=>a,"gate"=>get(m,:configured_trade_idle,nothing),"idle"=>get(m,:configured_post_return_idle,nothing),"reserve"=>r.final_agents[a].body.reserve)))
end
println(JSON3.write(r.portable_items.counts))
