include("animals_only.jl")
const B=LW.RDLBody
@testset "rabbit body and meat" begin
 s,ps=animal_trial_world();state=RabbitCompositionState(s)
 @test B.composition_energy(state.bodies[1])≈s.animals.energy[1]
 @test configured_rabbit_meal(state,s,1,900.,1.)≈900
 @test configured_rabbit_meal(nothing,s,1,900.,1.)==900
 s.animals.energy[1]=10.;configured_rabbit_composition_sync!(state,s)
 @test state.bodies[1].fat==0
 @test configured_rabbit_meal(state,s,1,900.,1.)<900
 @test 0<rabbit_composition_mobility(state,1)<1
 s.animals.energy[1]=5.;configured_rabbit_composition_sync!(state,s)
 @test state.bodies[1].collapsed
 @test rabbit_composition_mobility(state,1)==0
 s.animals.energy[1]=0.;configured_rabbit_composition_sync!(state,s)
 @test !state.bodies[1].alive
 @test state.max_balance_error<1e-8
end
@testset "rabbit natural metabolism three days" begin
 s,ps=animal_trial_world();state=RabbitCompositionState(s);physical=ComposedPredatorPhysiology.(ps);minds=PredatorMind.(eachindex(ps))
 rows=Any[]
 for t in 0:3*17280-1
  animal_trial_prepare!(s,ps,t;minds,physiology=physical)
  animal_trial_advance!(s,ps,t;minds,physiology=physical,rabbit_composition=state)
  if (t+1)%17280==0
   push!(rows,(day=div(t+1,17280),rabbits=count(s.alive),bodies=rabbit_composition_report(state,s),predators=trial_predator_report.(ps)))
   @test length(state.bodies)==length(s.alive)
   @test all(i->!s.alive[i] || isapprox(B.composition_energy(state.bodies[i]),s.animals.energy[i];atol=1e-7),eachindex(s.alive))
   @test all(c->c.fat<=RABBIT_COMPOSITION.fat_capacity+1e-8,state.bodies)
   G.snapshot(s;additional_predation_deaths=sum(p.visual.body.captures for p in ps))
   io=IOBuffer();serialize(io,(s,ps,state,physical,minds));seekstart(io)
   s,ps,state,physical,minds=deserialize(io)
  end
 end
 @test state.max_balance_error<1e-7
 write(get(ENV,"RABBIT_BODY_REPORT",joinpath(tempdir(),"rabbit-composition.json")),JSON3.write(rows))
end

include("../../src/lw/configured_paths/raptor_trial.jl")
@testset "birth weaning and raptor nutrition" begin
 s,ps=animal_trial_world();state=RabbitCompositionState(s)
 mother=findfirst(==(UInt8(2)),s.life.sex)
 s.life.litter[mother]=3;s.life.invested[mother]=24.
 G.rabbit_birth!(s,mother,s.ticks)
 configured_rabbit_composition_sync!(state,s)
 young=length(s.alive)
 @test length(state.bodies)==length(s.alive)
 @test state.dependent[young]
 @test B.composition_energy(state.bodies[young])≈s.animals.energy[young]
 before=s.animals.energy[young]
 s.life.born[young]=-G.RABBIT_LIFE.wean_days*G.RABBIT_LIFE.day_ticks
 configured_rabbit_composition_sync!(state,s)
 @test !state.dependent[young] && B.composition_energy(state.bodies[young])≈before
 input=JSON3.read(read(joinpath(@__DIR__,"predator_3d_spec.json"),String))
 bird=configured_raptor(s,input.scene);bird.target=1
 bird.visual.body.x=s.animals.x[1];bird.visual.body.z=s.animals.z[1]
 s.animals.energy[1]=10.;configured_rabbit_composition_sync!(state,s)
 expected=configured_rabbit_meal(state,s,1,RAPTOR_TRIAL.adult_food,(G.rabbit_height(s,1)/G.RABBIT_LIFE.adult_height)^3)
 for t in 1:100
  configured_raptor_capture!(bird,s,t;rabbit_composition=state)
  bird.captures>0 && break
 end
 @test bird.captures==1
 @test bird.meal≈expected
 @test bird.meal<RAPTOR_TRIAL.adult_food
end
