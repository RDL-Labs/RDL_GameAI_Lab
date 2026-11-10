using JSON3,Statistics,LinearAlgebra
function audit()
 roots=["raptor-resume550-20261110","raptor-west2216-90d-20261110","raptor-west2306-360d-20261110"]
 results=Any[]
 for root in roots
  path="C:/Users/ken_m/Documents/Codex/"*root*"/run"
  rows=[JSON3.read(line) for line in eachline(joinpath(path,"daily.jsonl"))]
  points=Any[]
  for i in 2:length(rows)
   r=rows[i];p=rows[i-1]
   push!(points,(day=Int(r.absolute_day),n=(r.rabbits+p.rabbits)/2,seconds=r.elapsed_seconds-p.elapsed_seconds,births=r.births-p.births,deaths=r.starvation-p.starvation,queries=r.neighbor_gpu.queries-p.neighbor_gpu.queries,evaluated=r.candidate_work.evaluated-p.candidate_work.evaluated,ground=r.predators[1].captures-p.predators[1].captures,bird=r.raptor.captures-p.raptor.captures,bird_present=r.raptor.present,gpu_queries=r.neighbor_gpu.gpu_queries-p.neighbor_gpu.gpu_queries))
  end
  n=[x.n for x in points];y=[x.seconds for x in points];fit=hcat(ones(length(n)),n)\y
  outliers=Any[]
  for x in points
   peers=filter(z->z.day!=x.day && abs(z.n-x.n)<=5,points)
   length(peers)>=5 || continue
   reference=median([z.seconds for z in peers])
   push!(outliers,merge(x,(peer_count=length(peers),peer_median=reference,ratio=x.seconds/reference,peer_queries=median([z.queries for z in peers]),peer_evaluated=median([z.evaluated for z in peers]))))
  end
  sort!(outliers;by=x->x.ratio,rev=true)
  result=(run=root,first=first(points).day,last=last(points).day,n_days=length(points),correlation=cor(n,y),linear_r2=cor(n,y)^2,intercept=fit[1],seconds_per_rabbit=fit[2],top=outliers[1:min(6,end)])
  push!(results,result);println(JSON3.write(result))
 end
 write(joinpath(@__DIR__,"evidence/population-runtime-outliers.json"),JSON3.write(results))
end
audit()
