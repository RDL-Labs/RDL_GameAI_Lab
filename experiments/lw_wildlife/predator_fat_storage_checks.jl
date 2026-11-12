include("animals_only.jl")
const B=LW.RDLBody
new_composition(;available=100.,fat=20.,protein=60.)=B.Composition(;available,fat,protein,protein_min=30.,protein_target=60.,collapse_protein=45.)
@testset "bounded surplus storage" begin
 c=new_composition();before=B.composition_energy(c)
 @test B.composition_store_fat!(c;reserve_floor=50.,fat_capacity=40.,rate=3.,dt=2.)==6
 @test c.fat==26 && c.available==94 && B.composition_energy(c)==before
 @test B.composition_store_fat!(c;reserve_floor=50.,fat_capacity=40.,rate=100.)==14
 @test B.composition_store_fat!(c;reserve_floor=50.,fat_capacity=40.,rate=100.)==0
 @test c.fat==40 && B.composition_energy(c)==before
 c=new_composition(available=52.)
 @test B.composition_store_fat!(c;reserve_floor=50.,fat_capacity=100.,rate=10.)==2
 @test c.available==50
 @test B.composition_store_fat!(c;reserve_floor=50.,fat_capacity=100.,rate=10.)==0
 c=new_composition(protein=55.)
 @test B.composition_store_fat!(c;reserve_floor=0.,fat_capacity=100.,rate=10.)==0
 c=new_composition(fat=120.)
 @test B.composition_store_fat!(c;reserve_floor=0.,fat_capacity=100.,rate=10.)==0 && c.fat==120
 @test_throws ArgumentError B.composition_store_fat!(c;reserve_floor=-1.,fat_capacity=100.,rate=10.)
 c=new_composition();B.composition_consume!(c,1000.)
 @test B.composition_store_fat!(c;reserve_floor=0.,fat_capacity=100.,rate=10.)==0
end
function storage_trial()
 world,predators=animal_trial_world();predator=predators[1];physical=ComposedPredatorPhysiology(predator)
 daily=Any[];max_error=0.
 # 暫定固定・機構試験: 20日間毎朝450を直接給餌し移動なし。その後は絶食。
 for day in 1:26
  day<=20 && configured_predator_feed!(physical,predator,450.)
  for tick in ((day-1)*17280+1):day*17280
   predator.mode=physical.composition.collapsed ? :collapsed : :idle
   configured_trial_advance!(world,predator,tick;physiology=physical)
   max_error=max(max_error,abs(900+predator.eaten-predator.food-predator.spent))
   !predator.alive && break
  end
  push!(daily,(day,body=B.composition_snapshot(physical.composition),spent=predator.spent,eaten=predator.eaten))
  if day==10
   stream=IOBuffer();serialize(stream,(predator,physical));seekstart(stream)
   predator,physical=deserialize(stream) # Continue through real serialized compartments.
  end
  !predator.alive && break
 end
 @test max_error<1e-5
 @test daily[1].body.fat>450
 @test maximum(d.body.fat for d in daily)<=900+1e-8
 @test daily[20].body.fat≈900
 @test daily[end].body.fat<daily[20].body.fat
 @test all(d.body.protein≈600 for d in daily[1:20])
 @test physical.body.reserve==predator.food
 write(get(ENV,"FAT_STORAGE_REPORT",joinpath(tempdir(),"predator-fat-storage.json")),JSON3.write((conditions=(feeding_days=20,daily_feed=450.,days=26,rule=PREDATOR_COMPOSITION),max_balance_error=max_error,daily)))
end
@testset "predator storage and depletion" begin
 storage_trial()
end
