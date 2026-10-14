include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
out=ARGS[1]
native_main([out,"--spec",joinpath(@__DIR__,"search_review_spec.json")])
r=JSON3.read(read(joinpath(out,"result.json"),String))
input=JSON3.read(read(joinpath(out,"spec.json"),String))
validate_integrated(r,input)
@testset "daily conservation and carryover" begin
 for (i,d) in enumerate(r.daily)
  @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(a.inventory+a.personal_stock for a in values(d.physical))
  i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
  for a in IDS
   previous=i==1 ? 0 : sum(values(r.daily[i-1].counts[a]))
   @test sum(values(d.counts[a]))-previous==17280
  end
 end
end
