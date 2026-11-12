include("animals_only.jl")
const B=LW.RDLBody
@testset "continuous fat support" begin
 makebody(g,f)=B.Composition(available=g,fat=f,protein=600.,protein_min=300.,protein_target=600.,collapse_protein=450.)
 for (g,expected_fat) in ((300.,0.),(150.,5.),(30.,9.),(0.,10.))
  c=makebody(g,450.);before=B.composition_energy(c)
  B.composition_consume!(c,10.;fat_support_level=300.)
  @test c.fat≈450-expected_fat
  @test before-B.composition_energy(c)≈10
  @test c.protein==600
 end
 c=makebody(150.,1.);B.composition_consume!(c,10.;fat_support_level=300.)
 @test c.available==141 && c.fat==0 && c.protein==600
 c=makebody(2.,1.);B.composition_consume!(c,10.;fat_support_level=300.)
 @test c.available==0 && c.fat==0 && c.protein==593
 @test_throws ArgumentError B.composition_consume!(c,1.;fat_support_level=-1.)
 # Compare identical resting expenditure, no meals; actual predator adapter for new.
 s,ps=animal_trial_world();p=ps[1];physical=ComposedPredatorPhysiology(p)
 old=deepcopy(physical.composition);rows=Any[];max_error=0.
 for t in 0:3*17280
  if t>0
   p.mode=physical.composition.collapsed ? :collapsed : :idle
   configured_trial_advance!(s,p,t;physiology=physical)
   B.composition_consume!(old,300/17280)
   B.composition_repair!(old,PREDATOR_COMPOSITION.repair_per_tick)
  end
  max_error=max(max_error,abs(900+p.eaten-p.spent-B.composition_energy(physical.composition)))
  if t%8640==0
   push!(rows,(day=t/17280,old=B.composition_snapshot(old),
     current=B.composition_snapshot(physical.composition),hunger=predator_hunger(p,physical)))
  end
 end
 @test rows[2].current.available>rows[2].old.available
 @test rows[2].current.fat<rows[2].old.fat
 @test rows[2].hunger>rows[1].hunger
 @test max_error<1e-6
 @test rows[end].current.usable≈rows[end].old.usable atol=1e-6
 before=predator_hunger(p,physical)
 # Separate living hungry body for food response and persistence check.
 s,ps=animal_trial_world();p=ps[1];physical=ComposedPredatorPhysiology(p)
 B.composition_consume!(physical.composition,10.;fat_support_level=300.)
 p.food=B.composition_energy(physical.composition)
 h=predator_hunger(p,physical)
 configured_predator_feed!(physical,p,100.)
 @test predator_hunger(p,physical)<h
 io=IOBuffer();serialize(io,(p,physical));seekstart(io);p2,b2=deserialize(io)
 @test B.composition_snapshot(b2.composition)==B.composition_snapshot(physical.composition)
 report=(rows=rows,max_balance_error=max_error,condition="no food, rest, 300 energy/day; actual predator adapter")
 write(get(ENV,"FAT_SUPPORT_REPORT",joinpath(tempdir(),"fat-support.json")),JSON3.write(report))
 for row in rows
  println(JSON3.write(row))
 end
end
