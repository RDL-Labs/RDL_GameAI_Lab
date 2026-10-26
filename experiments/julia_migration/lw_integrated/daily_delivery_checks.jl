using Test
include("../../../integrations/lightweight_julia/native.jl")
@testset "configured daily delivery" begin
    s=configured_daily_delivery_state();day=100_000_000
    request(t;ret=false,hungry=false,load=0,home=true,stock=3)=configured_daily_delivery_request!(s,ret,hungry,load,home,stock,t,day)
    @test !request(0)
    configured_daily_delivery_deposit!(s,0,0,day)
    @test !s["completed"]
    configured_daily_delivery_deposit!(s,2,1,day)
    @test s["completed"]
    @test request(2)
    @test request(3;hungry=true) # Stored food is a reason to stay.
    @test request(4;hungry=true,home=false) # Return using last observed stock.
    @test !request(5;hungry=true,stock=0)
    @test request(6;hungry=true,stock=0,load=1)
    configured_daily_delivery_deposit!(s,1,7,day)
    @test s["completions"]==1
    @test !request(day)
    @test !s["completed"]
    @test request(day+1;ret=true)
    configured_daily_delivery_deposit!(s,1,day+2,day)
    @test s["completions"]==2
end
