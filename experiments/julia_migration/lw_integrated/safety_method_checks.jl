include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "continuous warning methods" begin
 rows=[D("ref"=>string(i),"cost"=>1.,"load"=>0,"resistance"=>1.5) for i in 0:4]
 move=D("energy"=>D("rows"=>rows))
 view(fs)=D("coverage"=>"complete","features"=>fs)
 far=view([D("forward"=>10.,"right"=>0.,"distance"=>10.)])
 near=view([D("forward"=>2.,"right"=>2.,"distance"=>sqrt(8.)),D("forward"=>2.,"right"=>-2.,"distance"=>sqrt(8.))])
 s=safety_state();l=BasicLoop("safe")
 @test safety_methods!(s,l,far,move,"far")===nothing
 p=safety_methods!(s,l,near,move,"1")
 @test p["safety"] && !(get(p,"direction",nothing)==2)
 s2=safety_state();l2=BasicLoop("safe")
 @test safety_methods!(s2,l2,view(reverse(near["features"])),move,"1")["method"]==p["method"]
 s["accepted"]=true;safety_methods!(s,l,near,move,"2")
 @test l.methods[p["method"]].H==1
 @test l.H==1
 for i in 3:12;s["accepted"]=true;safety_methods!(s,l,near,move,string(i));end
 @test length([n for n in values(l.methods) if n.last_selected>0])>1
 partial=D("coverage"=>"partial","features"=>Any[])
 s["accepted"]=true;safety_methods!(s,l,partial,move,"partial")
 @test s["active"] && s["H"]==1
 @test last(l.events).E==1
 clear=view(Any[])
 for i in 1:4;s["accepted"]=true;safety_methods!(s,l,clear,move,"clear$i");end
 @test !s["active"] && s["releases"]==1
 @test l.H==0
 @test length(l.methods)<=8
end
out=ARGS[1]
for mode in ("legacy","continuous")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--hazards","mixed","--running","on","--food-body","on","--safety-methods",mode,"--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="continuous"
  @testset "living safety methods" begin
   @test all(s.sequence>0 for s in values(r.safety_methods))
   @test all(length(s.methods)<=13 for s in values(r.safety_methods))
   @test all(length(s.events)<=32 for s in values(r.safety_methods))
  end
 end
end
