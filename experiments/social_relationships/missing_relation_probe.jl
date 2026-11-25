# Isolated seeded-MB design probe; NOT connected to normal LW.
# Recipes, liking and remembered offers below are explicit experimental priors.
using JSON3, Test
const RULE=(depth=3,temperature=.25)
const Bag=Dict{Symbol,Int}
struct Relation
 name::String
 inputs::Bag
 outputs::Bag
 requires::Bag # available facilities, not consumed
 cost::Float64
 confidence::Float64
end
has(b,need)=all(get(b,k,0)>=v for (k,v) in need)
function apply(b,r)
 has(b,r.inputs)&&has(b,r.requires)||return nothing
 result=copy(b)
 for (k,v) in r.inputs;result[k]=get(result,k,0)-v;end
 for (k,v) in r.outputs;result[k]=get(result,k,0)+v;end
 result
end
# Goal-directed evaluation over remembered transformations. No item-name rule in scoring.
function outlook(b,relations,desires,depth=RULE.depth)
 best=(value=0.,path=String[],goal=nothing)
 for (goal,worth) in desires
  if get(b,goal,0)>0 && worth>best.value
   best=(value=worth,path=["consume:"*string(goal)],goal=goal)
  end
 end
 depth==0 && return best
 for r in relations
  after=apply(b,r);after===nothing && continue
  next=outlook(after,relations,desires,depth-1)
  value=r.confidence*next.value-r.cost
  if value>best.value;best=(value=value,path=vcat([r.name],next.path),goal=next.goal);end
 end
 best
end
function evaluate(b,recipes,desires,opportunities)
 before=outlook(b,recipes,desires)
 rows=Any[(name="continue",gain=0.,goal=before.goal,path=before.path)]
 for r in opportunities
  after=apply(b,r);after===nothing && continue
  next=outlook(after,recipes,desires)
  # If unsuccessful, retain the original attainable goal; expenditure still counts.
  gain=r.confidence*(next.value-before.value)-r.cost
  push!(rows,(name=r.name,gain=gain,goal=next.goal,path=vcat([r.name],next.path)))
 end
 # Same predicted outcome plus extra cost is dominated by continuing.
 # This is a common outcome comparison, not a same-item prohibition.
 viable=filter(r->r.name=="continue"||r.gain>0,rows)
 weights=exp.([r.gain for r in viable]./RULE.temperature);weights./=sum(weights)
 (before=before,candidates=rows,viable=[r.name for r in viable],probabilities=weights,
  selected=viable[argmax(weights)].name)
end
const recipes=[Relation("cook_plain",Bag(:fish=>1),Bag(:plain=>1),Bag(:fire=>1),.2,1.),
 Relation("cook_salted",Bag(:fish=>1,:salt=>1),Bag(:salted=>1),Bag(:fire=>1),.2,1.)]
const desires=Dict(:salted=>3.,:plain=>1.5,:fruit=>1.)
const offers=[Relation("trade_fruit_for_salt",Bag(:fruit=>1),Bag(:salt=>1),Bag(),.1,.9),
 Relation("gather_salt",Bag(),Bag(:salt=>1),Bag(),.8,1.),
 Relation("swap_salt",Bag(:salt=>1),Bag(:salt=>1),Bag(),.1,1.),
 Relation("give_salt",Bag(:salt=>1),Bag(),Bag(),.1,1.)]
base=Bag(:fish=>1,:fire=>1,:fruit=>1)
results=Dict{String,Any}()
results["missing_salt"]=evaluate(base,recipes,desires,offers)
results["has_salt"]=evaluate(merge(base,Bag(:salt=>1)),recipes,desires,offers)
results["no_fish"]=evaluate(Bag(:fire=>1,:fruit=>1),recipes,desires,offers)
results["no_fire"]=evaluate(Bag(:fish=>1,:fruit=>1),recipes,desires,offers)
results["unknown_recipe"]=evaluate(base,recipes[1:1],desires,offers)
results["no_desire"]=evaluate(base,recipes,Dict{Symbol,Float64}(),offers)
results["no_known_partner"]=evaluate(base,recipes,desires,offers[2:end])
results["low_trust"]=evaluate(base,recipes,desires,vcat([Relation(offers[1].name,offers[1].inputs,offers[1].outputs,Bag(),.1,.1)],offers[2:end]))
# Quantity changes may matter even when the exchanged material has the same name.
large=[Relation("cook_large",Bag(:fish=>1,:salt=>2),Bag(:large=>1),Bag(:fire=>1),.2,1.)]
more=Relation("salt_one_for_two",Bag(:salt=>1),Bag(:salt=>2),Bag(),.1,1.)
results["same_kind_more_needed"]=evaluate(merge(base,Bag(:salt=>1)),large,Dict(:large=>3.),[more,offers[3]])
@testset "missing relation drives acquisition" begin
 @test results["missing_salt"].selected=="trade_fruit_for_salt"
 @test results["missing_salt"].candidates[2].path==["trade_fruit_for_salt","cook_salted","consume:salted"]
 for name in ["has_salt","no_fish","no_fire","unknown_recipe","no_desire"]
  @test results[name].selected=="continue"
  @test results[name].viable==["continue"]
 end
 @test results["no_known_partner"].selected=="gather_salt"
 @test results["low_trust"].selected=="gather_salt"
 @test results["same_kind_more_needed"].selected=="salt_one_for_two"
 @test !("swap_salt" in results["same_kind_more_needed"].viable)
 @test base==Bag(:fish=>1,:fire=>1,:fruit=>1)
end
write(joinpath(@__DIR__,"missing_relation_result.json"),JSON3.write(results))
for name in sort(collect(keys(results)));r=results[name];println(name," => ",r.selected," ",JSON3.write([(name=x.name,gain=x.gain) for x in r.candidates]));end
