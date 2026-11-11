using JSON3,Serialization
const root=ARGS[1];const out=ARGS[2]
include(joinpath(root,"source/src/lw/LW.jl"))
input=JSON3.read(read(joinpath(root,"source/input.json"),String),Dict{String,Any});du=input["clock"]["day_us"]
cases=Tuple{Int,String}[]
for file in readdir(joinpath(root,"run");join=true)
 occursin(r"day-\d+\.json$",file) || continue
 record=JSON3.read(read(file,String),Dict{String,Any})
 for a in LW.IDS
  !record["home_activity"]["totals"][a]["inside"] && push!(cases,(record["day"],a))
 end
end
sort!(cases)
rows=Any[]
for (day,a) in cases
 s=deserialize(joinpath(root,"run/checkpoints/day-"*lpad(day,3,'0')*".jls")).state
 ev=[e for e in s[:events] if get(e,"actor",nothing)==a && (day-1)*du<=get(e,"us",0)<day*du]
 compact=[Dict(k=>get(e,k,nothing) for k in ("us","phase","action","status","method","purpose_family","target","selection_mode","configured_rule","reason")) for e in ev]
 for e in compact;e["second"]=(e["us"]-(day-1)*du)/1e6;end
 plan=s[:mb_maps][a]["daily_plan"]
 row=(day,actor=a,events=compact,plan=plan,body_policy=s[:configured_body_states][a],physical=s[:daily][end]["physical"][a],focus=s[:mb_maps][a]["task_focus"],sleep=s[:learning][a]["sleep"],home_activity=s[:daily][end]["home_activity"])
 push!(rows,row)
 println(JSON3.write((day,actor=a,events=length(compact),last_rule=get(last(ev),"configured_rule",nothing))))
 s=nothing;GC.gc()
end
write(out,JSON3.write(rows))
