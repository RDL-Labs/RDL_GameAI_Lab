using JSON3, Statistics
const run=abspath(ARGS[1]);const destination=abspath(ARGS[2])
const capture=Ref(false);const stop_at=Ref(0);const calls=Any[];const batches=Any[]
struct ProbeDone <: Exception end
function gate_probe!(sec,args...)
 sec>=stop_at[] && throw(ProbeDone())
 capture[]=sec>=stop_at[]-512
end
include(joinpath(run,"source/integrations/lightweight_julia/native.jl"))
for f in ("learning/mb_map.jl","learning/mb_sleep.jl","decision/relation_field.jl")
 include(joinpath(@__DIR__,"../../src/lw",f))
end
source=read(joinpath(@__DIR__,"../../src/lw/learning/mb_parent.jl"),String)
Base.include_string(Main,replace(source,"function mb_parent_candidates!("=>"function original_parent_candidates!("))
function mb_parent_candidates!(s,candidates,goal,target)
 t=time_ns();result=original_parent_candidates!(s,candidates,goal,target);elapsed=(time_ns()-t)/1e9
 if capture[]
  push!(calls,(count=length(candidates),seconds=elapsed))
  # Bounded samples spread across the window, with the largest batch retained separately.
  if length(calls)%64==1 || isempty(batches) || length(candidates)>maximum(length(b) for b in batches)
   rows=Any[]
   for p in candidates
    e=p["mb_parent_estimate"];model=s["parent_mb"]["models"][e["model"]]
    survival=mb_parent_survival!(model,e["mode"])
    push!(rows,Dict("baseline"=>e["baseline_actions"],"search"=>e["mode"]=="search",
      "mean"=>survival===nothing ? -1. : survival["restricted_mean"],
      "q80"=>survival===nothing || survival["q80"]===nothing ? -1. : survival["q80"],
      "last"=>survival===nothing ? 0. : survival["last_observed"],
      "rate"=>max(.0001,model["energy_rate"]),
      "expected_actions"=>e["expected_actions"],"upper_actions"=>e["upper_actions"],
      "energy"=>e["energy"],"expected_energy"=>e["expected_energy"]))
   end
   push!(batches,rows)
  end
 end
 result
end
input=JSON3.read(read(joinpath(run,"ordinary/input.json"),String));reports=Any[]
for day in (1,44,89)
 capture[]=false;empty!(calls);empty!(batches);stop_at[]=day*17280+60+512
 try
  run_integrated(input;resume_from=joinpath(run,"ordinary/checkpoints/day-"*lpad(day,3,'0')*".jls"))
 catch e
  e isa ProbeDone || rethrow()
 end
 row=Dict("day"=>day+1,"calls"=>copy(calls),"batches"=>deepcopy(batches));push!(reports,row)
 println(day+1," calls=",length(calls)," max=",maximum(c.count for c in calls)," estimate_seconds=",sum(c.seconds for c in calls));flush(stdout)
 write(destination,JSON3.write(reports))
end
