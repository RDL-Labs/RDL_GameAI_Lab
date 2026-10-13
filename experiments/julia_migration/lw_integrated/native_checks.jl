include(joinpath(@__DIR__,"native.jl"))
@testset "native World and configuration" begin
    a=native_scene(20261004);b=native_scene(20261004);c=native_scene(20261005)
    @test a==b
    @test a!=c
    @test length(a.obstacles)==6
    @test length(a.food)==8 && sum(f.stock for f in a.food)==96
    @test a.positions==[[-2.,4.],[0.,4.],[2.,4.]]
    @test native_clock().reserve_rate_scale==RS
    @test native_clock().strain_rate_scale==SS
    @test native_clock().sleep_rest_us==2_880_000_000
    @test_throws ErrorException native_scene(-1)
    @test_throws ErrorException native_options(["out","--bogus","1"])
    @test_throws ErrorException native_options(["out","--days"])
    @test native_options(["out","--days","2"])[2]["days"]=="2"
end

out=ARGS[1]
native_main([joinpath(out,"seed04"),"--days","3","--seed","20261004","--food","renewable","--hazards","crossing"])
native_main([joinpath(out,"replay"),"--spec",joinpath(out,"seed04","spec.json")])
native_main([joinpath(out,"seed05"),"--days","3","--seed","20261005","--food","renewable","--hazards","crossing"])
@testset "native frozen-input replay" begin
    @test JSON3.read(read(joinpath(out,"seed04","result.json"),String))==JSON3.read(read(joinpath(out,"replay","result.json"),String))
    @test read(joinpath(out,"seed04","spec.json"))==read(joinpath(out,"replay","spec.json"))
end
