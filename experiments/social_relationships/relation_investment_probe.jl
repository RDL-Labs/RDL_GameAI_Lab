# Local hypothesis only: not included by LW. Counterpart expectations are subjective
# fixture priors, not an oracle about actual goodwill or a causal claim about gifts.
using JSON3, Test
const TRADE_PROBE=(give_quantity=2.,receive_quantity=1.,give_value=1.,receive_value=1.4,
    safety_stock=2.,future_value=1.5,temperature=.35,h_scale=4.,uncertainty_band=1.,sleep_gain=.2,prior_samples=4.)
mutable struct RelationForecast
 probability::Float64
 residual::Float64
 variance::Float64
 strength::Float64
 samples::Int
end
RelationForecast(p)=RelationForecast(p,0.,0.,0.,0)
signed_h(m)=sign(m.residual)*max(0.,abs(m.residual)-TRADE_PROBE.uncertainty_band*sqrt(m.variance))/TRADE_PROBE.h_scale
function trade_choice(stock,relation;baseline_probability=.2)
 r=TRADE_PROBE
 # Material value and physical nutrition use distinct fields; equal nutrition/unit
 # is an explicit local simplification, not a market price or universal preference.
 material=r.receive_quantity*r.receive_value-r.give_quantity*r.give_value
 relation_expectation=(relation.probability-baseline_probability)*r.future_value
 deficit(x)=max(0.,r.safety_stock-x)^2
 anxiety=deficit(stock-r.give_quantity+r.receive_quantity)-deficit(stock)
 score=material+relation_expectation-anxiety
 feasible=stock>=r.give_quantity
 probability=feasible ? 1/(1+exp(-score/r.temperature)) : 0.
 (stock=stock,material=material,relation_expectation=relation_expectation,anxiety=anxiety,
  score=score,accept_probability=probability,feasible=feasible)
end
function settle_response!(m,observed,forecast)
 observed===nothing && return # unanswered/unobserved is not observed refusal
 r=TRADE_PROBE
 m.residual+=(Float64(observed)-forecast)*r.future_value
 m.variance+=forecast*(1-forecast)*r.future_value^2
 # Update next forecast only; current trial keeps its prior forecast.
 m.probability=(r.prior_samples*m.probability+Float64(observed))/(r.prior_samples+1)
 m.samples+=1
end
function sleep_consolidate!(m)
 before=signed_h(m);delta=TRADE_PROBE.sleep_gain*before;m.strength+=delta
 m.residual=0.;m.variance=0.
 (H_before=before,strength_change=delta,strength=m.strength)
end
function trace_case(p,outcomes)
 m=RelationForecast(p);rows=Any[]
 for (i,outcome) in enumerate(outcomes)
  forecast=m.probability
  # A completed exchange is not itself an observed change in the counterpart.
  offer=trade_choice(6.,m)
  settle_response!(m,outcome,forecast)
  push!(rows,(episode=i,choice=offer,forecast=forecast,observed=outcome,H=signed_h(m),next_probability=m.probability))
 end
 before_sleep=(residual=m.residual,variance=m.variance)
 consolidation=sleep_consolidate!(m)
 (initial_probability=p,rows=rows,before_sleep=before_sleep,sleep=consolidation)
end
cases=[merge((relation_label=label,subjective_reply_probability=p),trade_choice(stock,RelationForecast(p)))
 for (label,p) in (("unknown",.2),("sometimes",.5),("reliable",.8)) for stock in (2.,6.)]
positive=trace_case(.8,fill(true,8));negative=trace_case(.8,fill(false,8));mixed=trace_case(.8,[true,true,false,true,true,true,false,true])
@testset "trade expectation / anxiety / delayed relation evidence" begin
 rich=trade_choice(6.,RelationForecast(.8));poor=trade_choice(2.,RelationForecast(.8))
 @test rich.accept_probability>poor.accept_probability
 @test rich.material==poor.material
 @test rich.relation_expectation==poor.relation_expectation
 @test rich.anxiety==0 && poor.anxiety>0
 @test rich.accept_probability>trade_choice(6.,RelationForecast(.2)).accept_probability
 @test trade_choice(1.,RelationForecast(.8)).accept_probability==0
 m=RelationForecast(.8);trade_choice(6.,m);@test m.samples==0 && signed_h(m)==0
 settle_response!(m,nothing,.8);@test m.samples==0 && m.probability==.8
 @test negative.rows[end].next_probability<negative.initial_probability
 @test positive.rows[end].next_probability>positive.initial_probability
 @test negative.sleep.strength_change<0
 @test positive.sleep.strength_change>=0
 m=RelationForecast(.8);settle_response!(m,false,.8);sleep_consolidate!(m)
 @test sleep_consolidate!(m).strength_change==0
 # Material exchange succeeds while the separate relation forecast disappoints.
 @test negative.rows[1].choice.material==rich.material && negative.rows[1].H<0
end
output=isempty(ARGS) ? joinpath(@__DIR__,"relation_investment_result.json") : abspath(ARGS[1])
write(output,JSON3.write((rules=TRADE_PROBE,cases=cases,traces=(positive=positive,negative=negative,mixed=mixed))))
for c in cases;println(JSON3.write(c));end
println("RESULT ",output)
