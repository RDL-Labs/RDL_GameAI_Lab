using Serialization, JSON3
length(ARGS)==2 || error("usage: known_source_summary.jl BASE REPLAY")
base,out=abspath.(ARGS)
include(joinpath(out,"source/integrations/lightweight_julia/native.jl"))
function summarize(path)
 s=deserialize(path).state;m=s[:mb_maps]["npc_c"];ac=m["acquisition"];d=last(s[:daily]);b=d["digestion"]["npc_c"]["macronutrients"]
 records=ac["records"];prob=Dict{String,Float64}();selected=Dict{String,Int}()
 for r in records
  chosen=first(split(r["choice"],':'));selected[chosen]=get(selected,chosen,0)+1
  for (v,p) in zip(r["candidates"],r["probabilities"])
   k=v["technique"];prob[k]=get(prob,k,0.)+p/length(records)
  end
 end
 fishing=Dict{String,Int}()
 for e in s[:events]
  e["actor"]=="npc_c" && e["action"]=="fish" && 18*17280000000<=e["us"]<19*17280000000 || continue
  k=e["status"];fishing[k]=get(fishing,k,0)+1
 end
 Dict("methods"=>ac["methods"],"body"=>Dict(k=>b[Symbol(k)] for k in ["sugar","fat","tissue","ability"]),"counts"=>d["counts"]["npc_c"],"parent_H"=>s[:loops]["npc_c"]["food"].H,"known_sources"=>length(get(ac,"known_sources",Dict())),"known_source_ids"=>sort(collect(keys(acquisition_known_sources!(m,ac)))),"discoveries"=>[t["evidence"] for t in ac["trials"] if t["method"]=="explore" && t["status"]=="achieved"],"tail_records"=>length(records),"tail_probability"=>prob,"tail_selected"=>selected,"fishing_day19"=>fishing)
end
report=Dict("before_day18"=>summarize(joinpath(base,"checkpoints/day-018.jls")),"original_day19"=>summarize(joinpath(base,"checkpoints/day-019.jls")),"fixed_day19"=>summarize(joinpath(out,"checkpoints/day-019.jls")))
write(joinpath(out,"comparison.json"),JSON3.write(report))
for (k,v) in report
 println(k," ",JSON3.write(Dict("body"=>v["body"],"explore"=>v["methods"]["explore"],"prob"=>v["tail_probability"],"fish"=>v["fishing_day19"],"known"=>v["known_sources"])))
end



