using Test,Serialization,JSON3
include("../../src/lw/LW.jl")
const B=LW.RDLBody
@testset "capacity body integration" begin
    gut=LW.Digestion(macronutrients=true)
    raw=LW.HumanBody(gut.macro_body.body,gut.macro_body.hours_per_second)
    body=LW.configured_capacity_attach(raw)
    @test body.activity_capacity!==nothing
    @test LW.step(raw,"walk",0)[1].strain>0
    original=deepcopy(body.activity_capacity)
    predicted=LW.step(body,"walk",0)[1]
    @test body.activity_capacity.physical.wear==original.physical.wear
    @test predicted.strain==0
    for _ in 1:60
        body=LW.step(body,"walk",0)[1]
        body=LW.digest!(gut,body,1.;action="walk")
    end
    @test body.activity_capacity.physical.wear>0
    @test body.activity_capacity.fatigue>0
    @test body.strain==0
    before=body.activity_capacity.fatigue
    forecast=LW.metabolize(body,10.)
    forecast.activity_capacity.fatigue=2.
    @test body.activity_capacity.fatigue==before
    for _ in 1:60
        body=LW.step(body,"rest",0)[1]
        body=LW.digest!(gut,body,1.;action="rest",sleeping=true)
    end
    @test body.activity_capacity.fatigue==0
    @test body.activity_capacity.physical.wear==0
    @test haskey(LW.bodydict(body),"activity_capacity")
    io=IOBuffer();serialize(io,body);seekstart(io)
    @test deserialize(io).activity_capacity.fatigue==0
    body.activity_capacity.fatigue=.69;body.activity_capacity.physical.wear=.35
    loop=LW.BasicLoop("pending-home";probabilistic=true,seed=1)
    source="previous"
    LW.choose_method!(loop,Any[LW.D("method"=>"walk","priority"=>1.,"question"=>"movement_progress")],source)
    trial=loop.trial
    map=LW.D()
    LW.configured_capacity_request!(map,body,LW.D("distance"=>2.),false,0,1,loop)
    @test loop.trial===trial
    @test length(map["activity_capacity_plan"]["records"])==1
    @test !isempty(JSON3.write(map))
end
