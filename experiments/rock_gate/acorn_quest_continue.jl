using JSON3, Test, SHA, Serialization
length(ARGS)==3 || error("PREVIOUS_OUTPUT FINAL_DAY NEW_OUTPUT")
const previous=abspath(ARGS[1]);const days=parse(Int,ARGS[2]);const root=abspath(ARGS[3])
original=JSON3.read(read(joinpath(previous,"input.json"),String),Dict{String,Any})
const start_day=Int(original["config"]["days"])
start_day<days<=180 || error("final day must extend previous run")
saved=joinpath(previous,"checkpoints","day-"*lpad(start_day,3,'0')*".jls")
isfile(saved) || error("missing daily checkpoint")
ispath(joinpath(root,"source")) && error("fresh output required")
mkpath(root);cp(joinpath(previous,"source"),joinpath(root,"source"));cp(@__FILE__,joinpath(root,"runner.jl"))
input=deepcopy(original);input["config"]["days"]=days
check_input=deepcopy(input);check_input["config"]["days"]=start_day
@test check_input==original
write(joinpath(root,"input.json"),JSON3.write(input))
conditions=JSON3.read(read(joinpath(previous,"conditions.json"),String),Dict{String,Any})
conditions["days"]=days;conditions["continued_from"]=previous;conditions["source"]=joinpath(root,"source")
conditions["timing_note"]="first resumed day includes load and compilation; later intervals include checkpoint write"
write(joinpath(root,"conditions.json"),JSON3.write(conditions))
write(joinpath(root,"origin.json"),JSON3.write(Dict("checkpoint"=>saved,"checkpoint_sha256"=>bytes2hex(sha256(read(saved))),"start_after_day"=>start_day,"final_day"=>days)))
const last_day_wall=Ref(time_ns())
function record_quest_day(day,physical,maps,counts)
 wall=time_ns();seconds=(wall-last_day_wall[])/1e9;last_day_wall[]=wall
 row=Dict("day"=>day,"wall_seconds_since_previous_day"=>seconds,"physical"=>physical,"quest_stages"=>Dict(a=>m["training_quest"]["stage"] for (a,m) in maps),"cumulative_counts"=>counts)
 open(joinpath(root,"daily-progress.jsonl"),"a") do io;println(io,JSON3.write(row));end
 write(joinpath(root,"progress.json"),JSON3.write(Dict("completed_days"=>day,"target_days"=>days,"last_day_wall_seconds"=>seconds)))
end
include(joinpath(root,"source/integrations/lightweight_julia/native.jl"))
@test deserialize(saved).code==checkpoint_code_hash()
write(joinpath(root,"resume-ready.json"),JSON3.write(Dict("verified_source"=>true,"start_after_day"=>start_day)))
native_main([joinpath(root,"run"),"--spec",joinpath(root,"input.json"),"--resume-from",saved,"--checkpoint-dir",joinpath(root,"checkpoints")])
r=JSON3.read(read(joinpath(root,"run/result.json"),String))
before=JSON3.read(read(joinpath(previous,"run/result.json"),String))
@testset "training world continuation" begin
 @test length(r.daily)==days
 @test r.daily[1:start_day]==before.daily
 @test r.day_starts[1:start_day]==before.day_starts
 @test length(r.final_agents)==length(before.final_agents)
 for a in keys(r.mb_map)
  @test r.mb_map[a].training_quest==before.mb_map[a].training_quest
  for p in r.mb_map[a].configured_post_return_idle.records
   p.active || continue
   @test any(e->e.actor==String(a) && e.action=="eat" && e.status=="ate" && fld(e.us,17_280_000_000)==fld(p.us,17_280_000_000) && e.us<p.us,r.events)
  end
 end
 for d in r.daily
  @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
 end
end
write(joinpath(root,"completed.json"),JSON3.write(Dict("days"=>days,"verified"=>true,"continued_from"=>previous)))
println("CONTINUATION VERIFIED");flush(stdout)
