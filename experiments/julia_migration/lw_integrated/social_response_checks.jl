include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "own refusal evidence and bodily response" begin
    obs=D("self_id"=>"a","inventory"=>1,"body"=>D("reserve"=>90.),
        "messages"=>[D("id"=>"request1","sender"=>"b","kind"=>"request")],
        "others"=>[D("ref"=>"b","holding_food"=>true)])
    records=Records();p=pressure_update(nothing,records,"a")
    _,base=experienced_response(obs,records,p,"a","fixed")
    @test base["weight"]==0
    for i in 1:3
        records["r$i"]=D("agent_id"=>"a","target"=>"b","outcome"=>"refuse",
            "request_observation_id"=>"start$i","source_observation_id"=>"end$i")
    end
    p=pressure_update(nothing,records,"a")
    d,t=experienced_response(obs,records,p,"a","fixed")
    @test t["weight"]==1.8 || isapprox(t["weight"],1.8)
    @test t["give_probability"]<base["give_probability"]
    @test length(t["sources"])==3
    @test experienced_response(obs,records,p,"a","fixed")== (d,t)
    obs["body"]["reserve"]=20.
    _,hungry=experienced_response(obs,records,p,"a","fixed")
    @test hungry["give_probability"]<t["give_probability"]
    obs["inventory"]=0
    @test experienced_response(obs,records,p,"a","fixed")[1][1]=="refuse"
    @test_throws Exception experienced_response(obs,records,p,"wrong","fixed")
    for r in values(records);r["outcome"]="no_response_observed";end
    p=pressure_update(nothing,records,"a")
    @test experienced_response(obs,records,p,"a","fixed")[2]["weight"]==0
end
out=ARGS[1]
for mode in ("legacy","experience")
    dir=joinpath(out,mode)
    native_main([dir,"--days","3","--seed","20261005","--food","renewable","--social-response",mode])
    validate_integrated(JSON3.read(read(joinpath(dir,"result.json"),String)),JSON3.read(read(joinpath(dir,"spec.json"),String)))
end
scene=merge(native_scene(20261005),(positions=[[0.,0.],[.5,0.],[-.5,0.]],home=[0.,0.],obstacles=Any[],food=[(x=0.,z=4.,stock=12)],initial_inventory=[0,4,4],reserve=[30,90,90]))
cfg=(days=1,seed=20261005,food="finite",learning="full",hazards="off",social_response="experience")
mkpath(out);f=joinpath(out,"controlled.json");write(f,JSON3.write((scene=scene,clock=native_clock(),config=cfg)))
native_main([joinpath(out,"controlled"),"--spec",f])
r=JSON3.read(read(joinpath(out,"controlled","result.json"),String))
@testset "response in native life" begin
    @test sum(s.decisions for s in values(r.social_response))>0
    @test all(length(s.records)<=32 for s in values(r.social_response))
end
validate_integrated(r,JSON3.read(read(f,String)))
