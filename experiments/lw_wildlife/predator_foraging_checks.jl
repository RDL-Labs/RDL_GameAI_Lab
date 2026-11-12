include("animals_only.jl")
@testset "foraging outcome and hunger" begin
 m=PredatorMind(1);s,ps=animal_trial_world();p=ps[1]
 predator_foraging_result!(m,:hunt,100.,0.)
 @test m.estimates["foraging:uncovered_cost"]==100
 predator_foraging_result!(m,:visit_food,20.,0.)
 predator_foraging_result!(m,:hunt,10.,40.)
 @test m.estimates["foraging:uncovered_cost"]==90
 predator_foraging_result!(m,:rest,100.,0.)
 @test m.estimates["foraging:uncovered_cost"]==90
 predator_remember_place!(m,p,"food",0);site=first(keys(m.places))
 m.estimates[food_site_key(site,"unresolved")]=3.
 rows()=Any[LW.D("method"=>"hunt","action"=>:hunt,"priority"=>3.),LW.D("method"=>"other","action"=>:cross_river,"priority"=>0.)]
 p.food=900.;a=rows();configured_predator_foraging_pressure!(a,m,p)
 p.food=100.;b=rows();configured_predator_foraging_pressure!(b,m,p)
 @test b[1]["priority"]<a[1]["priority"]
 @test b[1]["decision_H"]>a[1]["decision_H"]
 @test m.loop.H==0
 @test length(b)==2
 io=IOBuffer();serialize(io,m);seekstart(io)
 @test deserialize(io).estimates==m.estimates
 predator_foraging_result!(m,:hunt,10.,200.)
 @test m.estimates["foraging:uncovered_cost"]==0
 @test all(isfinite,LW.method_distribution(m.loop,b))
 default_rows=rows(); explicit_rows=deepcopy(default_rows)
 foreach(c->c["decision_H"]=0.,explicit_rows)
 @test LW.method_distribution(m.loop,default_rows)==LW.method_distribution(m.loop,explicit_rows)
 rng_before=copy(m.loop.rng)
 configured_predator_foraging_pressure!(rows(),m,p)
 @test rand(copy(m.loop.rng))==rand(rng_before)
end

