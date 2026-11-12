include("animals_only.jl")
const B=LW.RDLBody
@testset "composition conservation" begin
 c=B.Composition(available=10.,fat=20.,protein=60.,protein_min=30.,protein_target=60.,collapse_protein=45.)
 @test B.composition_energy(c)==60
 @test B.composition_consume!(c,35.)==35
 @test c.available==0 && c.fat==0 && c.protein==55
 @test 0<B.composition_mobility(c)<1
 B.composition_consume!(c,10.);@test c.collapsed
 @test B.composition_repair!(c,100.)==0 && c.collapsed
 B.composition_feed!(c,40.);before=B.composition_energy(c)
 @test c.collapsed
 B.composition_repair!(c,15.)
 @test !c.collapsed && B.composition_energy(c)==before
 B.composition_consume!(c,1000.);@test !c.alive
 @test B.composition_feed!(c,100.)==0
 @test_throws ArgumentError B.composition_consume!(c,-1.)
end
function deprivation(;rescue=false)
 s,ps=animal_trial_world();p=ps[1];physical=ComposedPredatorPhysiology(p);mind=PredatorMind(1)
 max_balance_error=0.;rows=Any[];collapsed_tick=nothing;fed=false;recovered_tick=nothing
 for t in 1:4*17280
  predator_mind_plan!(s,p,ps,mind,t;physiology=physical)
  # 暫定試験条件: isolated starvation, no prey acquisition/movement; metabolism unchanged.
  p.mode=physical.composition.collapsed ? :collapsed : :idle
  configured_trial_advance!(s,p,t;physiology=physical)
  if physical.composition.collapsed && collapsed_tick===nothing
   collapsed_tick=t
   position=(p.visual.body.x,p.visual.body.z)
   predator_mind_plan!(s,p,ps,mind,t;physiology=physical)
   @test p.mode==:collapsed && mind.trial===nothing
   sequence=mind.loop.sequence
   predator_mind_plan!(s,p,ps,mind,t;physiology=physical)
   @test mind.loop.sequence==sequence
   @test predator_composition_factor(physical)==0.
   @test (p.visual.body.x,p.visual.body.z)==position
   io=IOBuffer();serialize(io,(p,physical));seekstart(io);saved_p,saved_physical=deserialize(io)
   @test saved_physical.composition.collapsed && saved_physical.body.reserve==saved_p.food
   if rescue
    @test configured_predator_feed!(physical,p,600.)==600
    @test physical.composition.collapsed
    fed=true
   end
  end
  if fed && !physical.composition.collapsed && recovered_tick===nothing
   recovered_tick=t
  end
  if t%17280==0 || !p.alive || t==collapsed_tick || t==recovered_tick
   push!(rows,(tick=t,food=p.food,spent=p.spent,eaten=p.eaten,alive=p.alive,body=B.composition_snapshot(physical.composition)))
  end
  max_balance_error=max(max_balance_error,abs(900+p.eaten-p.food-p.spent))
  !p.alive && break
 end
 @test max_balance_error<1e-6
 (;rows,collapsed_tick,recovered_tick,p,physical)
end
@testset "predator collapse and external feeding" begin
 a=deprivation();b=deprivation(rescue=true)
 @test a.collapsed_tick!==nothing && !a.p.alive
 @test b.recovered_tick>b.collapsed_tick
 @test b.p.alive
 io=IOBuffer();serialize(io,(b.p,b.physical));seekstart(io);p2,s2=deserialize(io)
 @test B.composition_snapshot(s2.composition)==B.composition_snapshot(b.physical.composition)
 @test s2.body.reserve==p2.food
 # Actual motion adapter slows a depleted but not collapsed body.
 s,ps=animal_trial_world();p=ps[1];physical=ComposedPredatorPhysiology(p)
 B.composition_consume!(physical.composition,675.);p.food=B.composition_energy(physical.composition)
 physical.body=LW.Body(10.,0.,p.food,0.);p.mode=:visit_food;p.visual.body.heading=0.
 @test 0<predator_composition_factor(physical)<1
 before=p.visual.body.distance;configured_trial_advance!(s,p,1;physiology=physical,scent_speed=.2)
 @test p.visual.body.distance-before<=.2*.75+1e-8
 write(get(ENV,"COMPOSITION_REPORT",joinpath(tempdir(),"predator-composition.json")),JSON3.write((starvation=a.rows,rescue=b.rows,collapse_tick=a.collapsed_tick,recovery_tick=b.recovered_tick)))
end


