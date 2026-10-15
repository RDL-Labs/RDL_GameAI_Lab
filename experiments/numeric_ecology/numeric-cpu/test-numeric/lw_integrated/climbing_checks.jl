include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "climb geometry, load and distinct method" begin
    low=[(x=0.,z=.5,radius=.15,height=.4)]
    high=RDLMigrationProbe.Circle[]
    w=(positions=Dict("a"=>(0.,0.)),obstacles=[RDLMigrationProbe.Circle(0.,.5,.15)],
       bodies=Dict("a"=>Body(10.,0.,90.,0.)),inventory=Dict("a"=>5))
    row=climb_sample(w,"a",0.,2,low,high,p->1.5)
    @test row["status"]=="performed"
    @test row["distance"]==1.
    @test row["landing_clear"]
    w.inventory["a"]=6
    @test climb_sample(w,"a",0.,2,low,high,p->1.5)["cost"]===nothing
    w.inventory["a"]=0
    push!(w.obstacles,RDLMigrationProbe.Circle(0.,1.,.1))
    @test !climb_sample(w,"a",0.,2,low,high,p->1.5)["landing_clear"]
    pop!(w.obstacles)
    push!(high,RDLMigrationProbe.Circle(0.,.7,.1))
    @test climb_sample(w,"a",0.,2,low,high,p->1.5)["cost"]===nothing
    empty!(high)
    w.bodies["a"]=Body(0.,0.,90.,0.)
    @test climb_sample(w,"a",0.,2,low,high,p->1.5)["status"]=="body_limited"
    w.bodies["a"]=Body(10.,0.,90.,0.)
    m=movement_observation(w,"a",Dict("a"=>0.),[(x=0.,z=2.,stock=12)], [12];visual_obstacles=high)
    @test length(m["visible"])==1
    @test m["energy"]["rows"][3]["cost"]===nothing
    rows=[climb_sample(w,"a",0.,i,low,high,p->1.5) for i in 0:4]
    loop=BasicLoop("food")
    candidates=climb_candidates(rows,m,first(m["visible"]),loop)
    @test !isempty(candidates) && all(c["action"]=="climb" for c in candidates)
    chosen=choose_method!(loop,candidates,"climb-op")
    @test startswith(chosen["method"],"climb_")
    resolve_method!(loop,"climb-op",true,false)
    @test loop.H==1 && loop.methods[chosen["method"]].H==0
end

out=ARGS[1]
for mode in ("off","on")
    dir=joinpath(out,mode)
    native_main([dir,"--days","3","--seed","20261005","--food","renewable","--low-obstacles","on","--climbing",mode])
    validate_integrated(JSON3.read(read(joinpath(dir,"result.json"),String)),JSON3.read(read(joinpath(dir,"spec.json"),String)))
end
# Same production entry and clock, controlled visible food beyond a low barrier.
scene=merge(native_scene(20261005),(positions=[[0.,0.],[3.,0.],[-3.,0.]],home=[0.,0.],
    obstacles=Any[],food=[(x=0.,z=2.,stock=12)],initial_inventory=[0,0,0],reserve=[90,90,90],
    low_obstacles=[(x=0.,z=.5,radius=.15,height=.4)]))
cfg=(days=1,seed=20261005,food="finite",learning="full",hazards="off",climbing="on",low_obstacles="on")
mkpath(out);specfile=joinpath(out,"controlled.json")
write(specfile,JSON3.write((scene=scene,clock=native_clock(),config=cfg)))
native_main([joinpath(out,"controlled"),"--spec",specfile])
r=JSON3.read(read(joinpath(out,"controlled","result.json"),String))
@testset "actual climb in common living loop" begin
    @test sum(s.performed for s in values(r.climbing))>0
    @test all(s.delta_mismatches==0 for s in values(r.climbing))
    @test all(length(s.records)<=32 for s in values(r.climbing))
end
validate_integrated(r,JSON3.read(read(specfile,String)))
