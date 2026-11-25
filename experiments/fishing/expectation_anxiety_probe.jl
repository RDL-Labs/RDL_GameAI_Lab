# Isolated design probe, not included by LW. No individual sensitivity differences.
using Random, Test, JSON3
const RULE=(steps=24,sleep_every=8,consumption_rate=.4,safety_stock=2.,cost_rate=.15,
    anxiety_gain=1.,h_scale=4.,h_gain=.35,sleep_gain=.2,uncertainty_band=1.,temperature=.35)
# All units are abstract food equivalents / trial time. These are experiment priors.
const METHODS=((name="fish_a",family="fish",p=.25,yield=4.,time=1.),
               (name="fish_b",family="fish",p=.25,yield=4.,time=1.),
               (name="gather",family="gather",p=.9,yield=1.2,time=.8))
mutable struct TrialMB
 residual::Float64
 variance::Float64
 strength::Float64
 hits::Int
 trials::Int
end
TrialMB()=TrialMB(0.,0.,0.,0,0)
h(m)=sign(m.residual)*max(0.,abs(m.residual)-RULE.uncertainty_band*sqrt(m.variance))/RULE.h_scale
function observe!(m,actual,expected,variance;success)
 m.residual+=actual-expected;m.variance+=variance;m.hits+=success;m.trials+=1
end
function probabilities(scores)
 z=exp.((scores.-maximum(scores))./RULE.temperature);z./sum(z)
end
function candidate(method,stock,mb)
 # Prior strength 4 observations; updated only from that location's observed outcomes.
 p=(4method.p+mb.hits)/(4+mb.trials)
 expected=p*method.yield
 cost=RULE.cost_rate*method.time
 post_stock=stock-RULE.consumption_rate*method.time
 anxiety=(1-p)*max(0.,RULE.safety_stock-post_stock)^2+p*max(0.,RULE.safety_stock-post_stock-method.yield)^2
 expectation=(expected-cost)/method.time
 (p=p,expected=expected,variance=p*(1-p)*method.yield^2,cost=cost,
  expectation=expectation,anxiety=anxiety,base=expectation-RULE.anxiety_gain*anxiety)
end
function choose(rng,prob)
 u=rand(rng);findfirst(x->u<=x,cumsum(prob)) |> x->something(x,length(prob))
end
# Prescribed counterfactual outcomes are held by the environment, not candidate().
# A has a long poor spell; B succeeds intermittently; gathering is steadier.
function outcome(method,step)
 method.name=="fish_a" ? step in (4,19) : method.name=="fish_b" ? step in (3,7,11,15,19,23) : step%10!=0
end
function run_case(initial_stock;seed=41)
 rng=MersenneTwister(seed);stock=initial_stock
 children=[TrialMB() for _ in METHODS];parents=Dict("fish"=>TrialMB(),"gather"=>TrialMB())
 rows=Any[];sleeps=Any[]
 for step in 1:RULE.steps
  fields=[candidate(METHODS[i],stock,children[i]) for i in eachindex(METHODS)]
  # Family mean prevents number of fishing sites from inflating family probability.
  family_scores=[sum(fields[i].base for i in (1,2))/2+parents["fish"].strength+RULE.h_gain*h(parents["fish"]),
                 fields[3].base+parents["gather"].strength+RULE.h_gain*h(parents["gather"])]
  family_prob=probabilities(family_scores)
  child_prob=probabilities([fields[i].base+children[i].strength+RULE.h_gain*h(children[i]) for i in (1,2)])
  selected_family=choose(rng,family_prob);index=selected_family==1 ? choose(rng,child_prob) : 3
  method=METHODS[index];field=fields[index];success=outcome(method,step);actual=success ? method.yield : 0.
  before=stock;stock=max(0.,stock-RULE.consumption_rate*method.time)+actual
  # Parent is credited only actual food, not approach/wait success. Same forecast
  # increment is evaluated at each scope; parent and child H aren't added in one score.
  observe!(children[index],actual,field.expected,field.variance;success)
  observe!(parents[method.family],actual,field.expected,field.variance;success)
  push!(rows,(step=step,stock_before=before,stock_after=stock,choice=method.name,actual=actual,
    fish_probability=family_prob[1],fish_a_conditional=child_prob[1],fields=fields,
    child_H=[h(m) for m in children],parent_H=Dict(k=>h(m) for (k,m) in parents)))
  if step%RULE.sleep_every==0
   records=Any[]
   for (scope,m) in vcat([(METHODS[i].name,children[i]) for i in eachindex(METHODS)],collect(pairs(parents)))
    before_h=h(m);change=RULE.sleep_gain*before_h;m.strength+=change
    push!(records,(scope=scope,H=before_h,change=change,strength=m.strength,residual=m.residual,variance=m.variance))
    m.residual=0.;m.variance=0. # applied exactly once; outcome counts remain
   end
   push!(sleeps,(step=step,records=records))
  end
 end
 (initial_stock=initial_stock,rows=rows,sleeps=sleeps,summary=(fish=count(r->startswith(r.choice,"fish"),rows),gather=count(r->r.choice=="gather",rows),final_stock=stock))
end
function checks()
 @testset "signed expectation / anxiety probe" begin
  low=candidate(METHODS[1],.5,TrialMB());high=candidate(METHODS[1],12.,TrialMB())
  @test low.expectation==high.expectation
  @test low.anxiety>high.anxiety==0
  @test candidate(METHODS[3],.5,TrialMB()).anxiety<low.anxiety
  @test candidate(METHODS[1],12.,TrialMB())==high # no world outcome input
  m=TrialMB();observe!(m,0.,1.,3.;success=false);@test h(m)==0 # normal miss
  for _ in 2:10;observe!(m,0.,1.,3.;success=false);end
  @test h(m)<0
  observe!(m,4.,1.,3.;success=true);@test h(m)<0 # one catch doesn't erase deficit
  positive=TrialMB();observe!(positive,4.,1.,3.;success=true);@test h(positive)>0
  @test probabilities([2.,2.])==[.5,.5]
  @test run_case(.5)==run_case(.5)
  @test first(run_case(12.).rows).fish_probability>first(run_case(.5).rows).fish_probability
 end
end
checks()
output=length(ARGS)>0 ? abspath(ARGS[1]) : joinpath(@__DIR__,"expectation_anxiety_result.json")
cases=[run_case(s) for s in (.5,3.,12.)]
# Open-loop matched evidence tests isolate H from changes in the chosen trajectory.
matched=Any[]
for scenario in ("misses","intermittent","early_win_then_misses")
 mb=TrialMB();trace=Any[]
 for step in 1:24
  win=scenario=="intermittent" ? step%4==0 : scenario=="early_win_then_misses" ? step==1 : false
  observe!(mb,win ? 4. : 0.,1.,3.;success=win)
  push!(trace,(step=step,actual=win ? 4. : 0.,H=h(mb),residual=mb.residual,variance=mb.variance))
 end
 push!(matched,(scenario=scenario,trace=trace))
end
write(output,JSON3.write((rules=RULE,methods=METHODS,cases=cases,matched=matched)))
for c in cases;println(JSON3.write((stock=c.initial_stock,summary=c.summary,first_fish_probability=c.rows[1].fish_probability)));end
println("RESULT ",output)
