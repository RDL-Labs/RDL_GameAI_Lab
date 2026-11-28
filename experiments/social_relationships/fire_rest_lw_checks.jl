using Test
include("../../src/lw/LW.jl")
@testset "fire rest connection gates" begin
    m=LW.D();h=(x=4.,z=0.);rows=[LW.D("ref"=>"0","cost"=>1.,"clear"=>true)]
    for i in 1:100
        LW.configured_fire_rest!(m,h,(0.,0.),(2.,0.),0.,rows,i*128_000_000;
            eligible=true,blocked=false,night=false,demand=0.)
    end
    @test 0<m["configured_fire_rest"]["fire_choices"]<100
    @test m["configured_fire_rest"]["rest_ticks"]>0
    for (blocked,night,demand) in ((true,false,0.),(false,true,0.),(false,false,1.))
        @test LW.configured_fire_rest!(m,h,(0.,0.),(2.,0.),0.,rows,1;
            eligible=true,blocked,night,demand)===nothing
    end
end
