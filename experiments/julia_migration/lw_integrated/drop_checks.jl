include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "ground cargo identity and conservation" begin
    w=(positions=Dict("a"=>(0.,0.),"b"=>(0.,0.),"c"=>(0.,0.)),obstacles=RDLMigrationProbe.Circle[],inventory=Dict("a"=>6,"b"=>0,"c"=>0))
    cargo=Dict(a=>Union{Nothing,String}[] for a in ("a","b","c"));append!(cargo["a"],["source$i" for i in 1:6])
    food=Any[(x=4.,z=4.,stock=12)];stock=[12];g=cargo_ground()
    @test cargo_transfer!(g,w,cargo,food,stock,"a","d1",1,"drop")=="dropped"
    @test w.inventory["a"]==5 && stock==[12,1]
    @test cargo_transfer!(g,w,cargo,food,stock,"a","d1",1,"drop")=="dropped"
    @test w.inventory["a"]==5
    @test_throws Exception cargo_transfer!(g,w,cargo,food,stock,"a","conflict",1,"drop")
    @test cargo_transfer!(g,w,cargo,food,stock,"b","r1",2,"recover";index=2)=="recovered"
    @test cargo["b"]==["source1"] && g["cross_actor"]==1
    @test cargo_transfer!(g,w,cargo,food,stock,"b","r1",2,"recover";index=2)=="recovered"
    @test w.inventory["b"]==1
    @test cargo_transfer!(g,w,cargo,food,stock,"a","d2",2,"drop")=="dropped"
    @test length(food)==3 # a just-emptied slot cannot change identity in this observation tick
    @test cargo_transfer!(g,w,cargo,food,stock,"c","r2",2,"recover";index=2)=="unavailable"
    @test sum(stock)+sum(values(w.inventory))==18
    @test cargo_transfer!(g,w,cargo,food,stock,"a","d3",3,"drop")=="dropped"
    @test length(food)==3 && stock[2]==1
    stock[2]=0 # renewal only touches original resource sites
    replenish_food!(stock,[(x=4.,z=4.,stock=12)])
    @test stock[2]==0
    @test_throws Exception cargo_transfer!(g,w,cargo,food,stock,"a","old",2,"drop")
end
@testset "drop is a means, not home success" begin
    low=[(x=0.,z=.5,radius=.15,height=.4)]
    w=(positions=Dict("a"=>(0.,0.)),obstacles=[RDLMigrationProbe.Circle(0.,.5,.15)],bodies=Dict("a"=>Body(10.,0.,90.,0.)),inventory=Dict("a"=>6))
    rows=[climb_sample(w,"a",0.,i,low,RDLMigrationProbe.Circle[],p->1.5) for i in 0:4]
    cs=drop_candidates(rows,w.bodies["a"],6,D("forward"=>2.,"right"=>0.))
    @test !isempty(cs)
    s=BasicLoop("home");c=choose_method!(s,cs,"drop-op")
    resolve_method!(s,"drop-op",true,false)
    @test s.H==1 && s.methods[c["method"]].H==0
    w.inventory["a"]=5
    @test climb_sample(w,"a",0.,2,low,RDLMigrationProbe.Circle[],p->1.5)["status"]=="performed"
    @test isempty(drop_candidates(rows,w.bodies["a"],6,nothing))
end
out=ARGS[1]
for mode in ("off","on")
    dir=joinpath(out,mode)
    native_main([dir,"--days","3","--seed","20261005","--food","renewable","--low-obstacles","on","--climbing","on","--dropping",mode])
    validate_integrated(JSON3.read(read(joinpath(dir,"result.json"),String)),JSON3.read(read(joinpath(dir,"spec.json"),String)))
end
scene=merge(native_scene(20261005),(positions=[[0.,0.],[3.,0.],[-3.,0.]],home=[0.,2.],obstacles=Any[],food=[(x=0.,z=4.,stock=12)],initial_inventory=[6,0,0],reserve=[90,90,90],low_obstacles=[(x=0.,z=.5,radius=.15,height=.4)]))
cfg=(days=1,seed=20261005,food="finite",learning="full",hazards="off",climbing="on",low_obstacles="on",dropping="on")
mkpath(out);f=joinpath(out,"controlled.json");write(f,JSON3.write((scene=scene,clock=native_clock(),config=cfg)))
native_main([joinpath(out,"controlled"),"--spec",f])
r=JSON3.read(read(joinpath(out,"controlled","result.json"),String))
@testset "drop in common living loop" begin
    @test r.dropped_cargo.dropped>0
    @test length(r.dropped_cargo.records)<=32
    @test length(r.dropped_cargo.sites)<=256
end
validate_integrated(r,JSON3.read(read(f,String)))
