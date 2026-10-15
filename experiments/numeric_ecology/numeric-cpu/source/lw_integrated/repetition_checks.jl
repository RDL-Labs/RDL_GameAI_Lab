using Test
D(ps...)=Dict{String,Any}(ps...)
check(ok,msg)=ok || error(msg)
include(joinpath(@__DIR__,"../lw_day/repetition_pressure.jl"))
@testset "finite lack-of-change pressure" begin
    s=repetition_state()
    for i in 1:10;repetition_result!(s,"$i",i*1_000_000,"rest",(:same,));end
    @test s["nodes"]["rest"]>=4
    cs=[D("method"=>"rest","priority"=>2.),D("method"=>"scan","priority"=>1.)]
    @test project_repetition!(s,cs)
    @test cs[1]["priority"]<cs[2]["priority"]
    @test length(cs)==2
    @test_throws ErrorException repetition_result!(s,"10",10_000_000,"rest",(:same,))
    r=repetition_state()
    for i in 1:10;repetition_result!(r,"$i",i*1_000_000,"rest",(:same,);changed=true);end
    @test isempty(r["nodes"])
    r=repetition_state()
    for i in 1:10;repetition_result!(r,"$i",i*1_000_000,"rest",(i,));end
    @test isempty(r["nodes"])
    repetition_result!(s,"night",1_000_000_000,nothing,(:same,))
    @test s["nodes"]["rest"]==0
    repetition_result!(s,"resume",1_001_000_000,"rest",(:same,))
    @test s["nodes"]["rest"]==0
    @test_throws ErrorException repetition_result!(s,"bad",1_002_000_000,"rest",(:same,);decay=-1.)
end
