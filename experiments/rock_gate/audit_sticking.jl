using JSON3, Test
root=normpath(joinpath(@__DIR__,"../.."))
prior=abspath(ARGS[1]);out=abspath(ARGS[2]);ispath(out) && error("fresh output required");mkpath(out)
snapshot=joinpath(out,"source");mkpath(snapshot)
cp(joinpath(prior,"source/src"),joinpath(snapshot,"src"))
cp(joinpath(prior,"source/integrations"),joinpath(snapshot,"integrations"))
path=joinpath(snapshot,"src/lw/simulation/day.jl")
code=read(path,String)
code=replace(code,"        Main.gate_probe!(sec,w,purposes,counts,spec.home)"=>"")
anchor="            counts[a][action]=get(counts[a],action,0)+1"
@assert count(anchor,code)==1
code=replace(code,anchor=>"            Main.sticking_probe!(sec,a,p,w.positions[a],before_yaw,yaw[a],plan,status,moves[a],spec.home)\n"*anchor)
write(path,code)
stats=Dict{String,Any}();history=Dict{String,Any}()
function sticking_probe!(sec,a,p,q,by,ay,plan,status,move,home)
 s=get!(stats,a) do
  Dict{String,Any}("walks"=>0,"blocked"=>0,"zero_movement"=>0,"gate_ticks"=>0,"gate_walks"=>0,
   "gate_no_feasible_walk"=>0,"min_gate_distance"=>Inf,"distance"=>0.,"period36_moving_returns"=>0,
   "examples"=>Any[],"movement_methods"=>Dict{String,Int}())
 end
 gate=hypot(p[1]-home[1],p[2]-(home[2]-5))
 s["min_gate_distance"]=min(s["min_gate_distance"],gate)
 near=gate<=2
 s["gate_ticks"]+=Int(near)
 near && (s["gate_no_feasible_walk"]+=Int(all(r["cost"]===nothing for r in move["energy"]["rows"])))
 d=hypot(q[1]-p[1],q[2]-p[2]);s["distance"]+=d
 if plan["action"] in ("walk","run","climb")
  s["walks"]+=1;s["blocked"]+=Int(status=="blocked");s["zero_movement"]+=Int(d<1e-10)
  s["gate_walks"]+=Int(near)
  m=get(plan,"method","none");s["movement_methods"][m]=get(s["movement_methods"],m,0)+1
 end
 h=get!(history,a,Any[])
 if length(h)==36
  old=popfirst!(h)
  if hypot(old.position[1]-q[1],old.position[2]-q[2])<1e-6 && s["distance"]-old.distance>1
   s["period36_moving_returns"]+=1
   length(s["examples"])<8 && push!(s["examples"],(sec=sec+1,position=q,distance_in_36s=s["distance"]-old.distance))
  end
 end
 push!(h,(position=q,distance=s["distance"]))
 if a=="npc_c" && mod(sec+1,17280)==0;println("AUDIT DAY $(div(sec+1,17280))");flush(stdout);end
end
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
native_main([joinpath(out,"run"),"--spec",joinpath(prior,"narrow/input.json")])
before=JSON3.read(read(joinpath(prior,"narrow/run/result.json"),String))
after=JSON3.read(read(joinpath(out,"run/result.json"),String))
@test before==after
write(joinpath(out,"audit.json"),JSON3.write(stats))
println(JSON3.write(stats))
