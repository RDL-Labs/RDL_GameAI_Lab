using Test, Random, Statistics
module Old
include(joinpath(abspath(ARGS[1]),"experiments/julia_migration/lw_integrated/native.jl"))
end
module New
include(joinpath(@__DIR__,"../lw_integrated/native.jl"))
end
out=abspath(ARGS[2]);mkpath(out);rng=MersenneTwister(417)
@testset "body deltas" begin
 for _ in 1:100, action in ("walk","run","climb","rest","eat"), clear in (true,false)
  damage=rand(rng);args=(10*(1-damage)*rand(rng),rand(rng),100*rand(rng),damage)
  load=rand(rng,0:12);r=1+4*rand(rng)
  a=Old.step(Old.Body(args...),action,load,r,clear)
  b=New.step(New.Body(args...),action,load,r,clear)
  @test Old.bodydict(a[1])==New.bodydict(b[1]) && a[2:3]==b[2:3] && a[4]==b[4]
  @test Old.JSON3.read(Old.JSON3.write(a[4]))==New.JSON3.read(New.JSON3.write(b[4]))
 end
end
@testset "candidate ordering" begin
 for _ in 1:500
  a=Old.BasicLoop("food");b=New.BasicLoop("food")
  cs=[Old.D("method"=>"m$i","priority"=>rand(rng,(-1.,0.,1.,2.)),"question"=>"q") for i in 1:rand(rng,1:12)]
  shuffle!(rng,cs)
  for c in cs
   rand(rng,Bool) || continue
   h=rand(rng,0:8);t=rand(rng,1:4);last=rand(rng,0:10);name=c["method"]
   a.methods[name]=Old.MethodNode(h,t,last);b.methods[name]=New.MethodNode(h,t,last)
  end
  @test Old.method_choice(a,cs)==New.method_choice(b,cs)
  snapshot=deepcopy(cs)
  @test Old.choose_method!(a,cs,"test")==New.choose_method!(b,cs,"test")
  @test cs==snapshot && Old.loop_snapshot(a)==New.loop_snapshot(b)
 end
 @test New.method_choice(New.BasicLoop("f"),Any[])===nothing
end
objects=[(x=rand(rng)*40-20,z=rand(rng)*50,radius=.5+rand(rng),height=rand(rng)*15,color=string(i)) for i in 1:50]
append!(objects,[(x=0.,z=3.,radius=1.,height=1.,color="low"),(x=0.,z=6.,radius=1.,height=12.,color="high"),(x=0.,z=6.,radius=1.,height=12.,color="tie")])
@testset "shared horizontal intersections" begin
 for sub in (false,true), yaw in 0.:15.:345., p in ((0.,0.),(3.,2.),(-4.,7.))
  @test Old.skyline_fan(objects,p,yaw,"v";subrays=sub)==New.skyline_fan(objects,p,yaw,"v";subrays=sub)
 end
 @test Old.skyline_fan([], (0.,0.),0.,"v")==New.skyline_fan([], (0.,0.),0.,"v")
end
function measure(label,f,g)
 f();g();rows=Any[]
 for i in 1:15, (variant,fn) in (isodd(i) ? (("old",f),("new",g)) : (("new",g),("old",f)))
  GC.gc();r=@timed fn();push!(rows,(variant=variant,seconds=r.time,bytes=r.bytes))
 end
 for v in ("old","new")
  rs=filter(x->x.variant==v,rows);println((label=label,variant=v,seconds=median(x.seconds for x in rs),bytes=median(x.bytes for x in rs)))
 end
 write(joinpath(out,label*".json"),New.JSON3.write(rows))
end
function body_batch(M)
 b=M.Body(10.,.2,60.,0.);s=0.
 for i in 1:10000
  _,_,_,d=M.step(b,"walk",i%12,1.5,true);s+=d["reserve"]
 end;s
end
function choice_batch(M)
 s=M.BasicLoop("f");cs=[M.D("method"=>"m$i","priority"=>Float64(i%3),"question"=>"q") for i in 1:12];v=0
 for _ in 1:10000;v+=length(M.method_choice(s,cs)["method"]);end;v
end
measure("body",()->body_batch(Old),()->body_batch(New))
measure("choice",()->choice_batch(Old),()->choice_batch(New))
measure("skyline",()->[Old.skyline_fan(objects,(0.,0.),0.,"v";subrays=true) for _ in 1:100],()->[New.skyline_fan(objects,(0.,0.),0.,"v";subrays=true) for _ in 1:100])
# Frozen integrated World, shortened only in number of days. Compare decoded
# records because immutable delta iteration order may differ from hash Dict order.
spec=New.JSON3.read(read(ARGS[3],String),Dict{String,Any});spec["config"]["days"]=length(ARGS)>=4 ? parse(Int,ARGS[4]) : 1
@assert spec["config"]["days"] in (1,10)
write(joinpath(out,"spec.json"),New.JSON3.write(spec))
Old.native_main([joinpath(out,"old"),"--spec",joinpath(out,"spec.json")])
New.native_main([joinpath(out,"new"),"--spec",joinpath(out,"spec.json")])
old=New.JSON3.read(read(joinpath(out,"old/result.json"),String),Dict{String,Any})
new=New.JSON3.read(read(joinpath(out,"new/result.json"),String),Dict{String,Any})
@test old==new
for r in (old,new)
 @test r["ended_us"]==spec["config"]["days"]*spec["clock"]["day_us"]
 @test all(sum(values(c))==spec["config"]["days"]*17280 for c in values(r["counts"]))
 @test r["initial_food"]+r["replenished_food"]==r["ground"]+get(r,"shared_stock",0)+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
 @test all(isfinite(v) for s in values(r["final_agents"]) for v in values(s["body"]) if v isa Number)
end
write(joinpath(out,"comparison.json"),New.JSON3.write((equal=true,days=spec["config"]["days"],scope="exact decoded full results",invariants=true)))
println("PASS: integrated decoded result equality and invariants")
