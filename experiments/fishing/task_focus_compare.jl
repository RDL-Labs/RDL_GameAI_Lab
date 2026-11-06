using JSON3
base=ARGS[1];on=ARGS[2]
for p in (base,on)
 r=JSON3.read(read(joinpath(p,"result.json"),String));m=JSON3.read(read(joinpath(p,"metrics.json"),String));d=last(r.daily);prior=JSON3.read(read(joinpath(ARGS[3],"run/result.json"),String)).daily[23]
 counts=Dict{String,Int}()
 for (a,c) in pairs(d.counts),(k,n) in pairs(c);counts[String(k)]=get(counts,String(k),0)+n-get(prior.counts[a],k,0);end
 f=Dict(String(a)=>get(v,:task_focus,nothing) for (a,v) in pairs(r.mb_map))
 focus=Dict(a=>(v===nothing ? nothing : Dict("skipped"=>v.skipped,"wakeups"=>v.wakeups)) for (a,v) in f)
 println(JSON3.write(Dict("path"=>p,"metrics"=>m,"counts"=>counts,"focus"=>focus,"reserve"=>Dict(String(a)=>v.body.reserve for (a,v) in pairs(r.final_agents)),"ground"=>r.ground,"consumed"=>r.consumed)))
end
