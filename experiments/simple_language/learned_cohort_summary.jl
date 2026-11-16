using JSON3
root=abspath(only(ARGS))
summary=Dict{String,Any}()
for stage in ("continue20",isdir(joinpath(root,"mixed20-v2")) ? "mixed20-v2" : "mixed20")
 path=joinpath(root,stage)
 result=JSON3.read(read(joinpath(path,"run/result.json"),String))
 applied=Dict{String,Any}()
 for (actor,relation) in pairs(result.social_relationships)
  records=relation.gradient_maps.records
  cues=[c.communication_prediction for r in records for c in r.candidates if haskey(c,:communication_prediction)]
  applied[string(actor)]=Dict("retained_candidate_predictions"=>length(cues),
   "changed_predictions"=>count(c->c.prior!=c.probability,cues))
 end
 summary[stage]=Dict("completion"=>JSON3.read(read(joinpath(path,"completed.json"),String)),
  "control"=>JSON3.read(read(joinpath(path,"learned_control.json"),String)),
  "reserve"=>Dict(string(a)=>v.body.reserve for (a,v) in pairs(result.final_agents)),
  "retained_gradient_evidence"=>applied)
end
write(joinpath(root,"summary.json"),JSON3.write(summary))
println(JSON3.write(summary))
