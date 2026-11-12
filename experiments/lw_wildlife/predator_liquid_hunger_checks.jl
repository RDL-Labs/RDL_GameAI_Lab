include("animals_only.jl")
const B=LW.RDLBody
@testset "liquid hunger persists while fat supports consumption" begin
 s,ps=animal_trial_world();p=ps[1];physical=ComposedPredatorPhysiology(p)
 c=physical.composition
 initial=B.composition_energy(c)
 @test predator_food_deficit(p,physical)==150.
 B.composition_consume!(c,150.)
 p.food=B.composition_energy(c)
 h=predator_hunger(p,physical);fat=c.fat
 @test c.available==0 && h>0
 B.composition_consume!(c,100.);p.food=B.composition_energy(c)
 @test c.available==0 && c.fat==fat-100 && c.protein==600.
 @test predator_hunger(p,physical)==h
 @test B.composition_energy(c)==initial-250
 # High fat cannot suppress hunger or hold an idle decision.
 c.fat=900.;p.food=B.composition_energy(c)
 mind=PredatorMind(1)
 rival=(actor=nothing,distance=Inf)
 mind.selected=LW.D("action"=>:idle);mind.trial=LW.D()
 @test !configured_predator_idle_hold!(mind,p,rival,1,physical)
 rows=predator_candidates(mind,p,rival,nothing,1;physiology=physical)
 @test any(x->x["action"]==:hunt,rows)
 hunt=only(filter(x->x["action"]==:hunt,rows))
 @test hunt["food_demand_forecast"].deficit==300
 @test hunt["foraging_pressure"].hunger==h
 before=B.composition_energy(c)
 @test configured_predator_feed!(physical,p,300.)==300
 @test B.composition_energy(c)==before+300
 @test predator_food_deficit(p,physical)==0
 @test configured_predator_idle_hold!(mind,p,rival,2,physical)
 rows=predator_candidates(mind,p,rival,nothing,1;physiology=physical)
 @test !any(x->x["action"]==:hunt,rows)
 io=IOBuffer();serialize(io,(p,physical));seekstart(io);p2,b2=deserialize(io)
 @test predator_hunger(p2,b2)==0
 @test B.composition_snapshot(b2.composition)==B.composition_snapshot(c)
 # Legacy physiology remains based on total reserve.
 @test predator_food_deficit(p)==max(0.,PREDATOR_ANIMAL_TRIAL.initial_food-p.food)
end
