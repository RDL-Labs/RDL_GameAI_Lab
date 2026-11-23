using Test, Serialization
include("../../src/lw/LW.jl")
const D=LW.D
function test_move()
    D("energy"=>D("rows"=>[D("status"=>"performed","distance"=>.5) for _ in LW.ANGLES]),"run_rows"=>Any[])
end
target(distance;ref=7)=D("forward"=>Float64(distance),"right"=>0.,"distance"=>Float64(distance),"ref"=>ref)
function select_probe!(loop,source)
    LW.choose_method!(loop,[D("method"=>"approach","priority"=>0.,"question"=>"progress")],source)
end
@testset "observed movement uses common forecast difference" begin
    move=test_move();plan=D("action"=>"walk","direction"=>0,"approach_angle"=>0.)
    forecast=LW.navigation_forecast(plan,move,target(10),"food")
    @test forecast["expected"]≈1.
    @test LW.navigation_forecast_result(forecast,nothing,[target(9.5)])==(1.,1.)
    @test LW.navigation_forecast_result(forecast,nothing,[target(10)])==(1.,0.)
    @test LW.navigation_forecast_result(forecast,nothing,[target(9.5;ref=8)])===nothing
    @test LW.navigation_forecast_result(forecast,nothing,Any[])===nothing
    @test LW.navigation_forecast(plan,move,nothing,"food")===nothing
    coarse=target(10);coarse["distance_estimated"]=true
    @test LW.navigation_forecast(plan,move,coarse,"food")===nothing
    @test LW.navigation_forecast_result(forecast,nothing,[coarse])===nothing
    # Deliberate detour: moving farther away as forecast is not a failure.
    detour=merge(plan,D("approach_angle"=>180.))
    detour_forecast=LW.navigation_forecast(detour,move,target(10),"food")
    evidence=LW.navigation_forecast_result(detour_forecast,nothing,[target(10.5)])
    @test evidence==(-1.,-1.)
    loop=LW.BasicLoop("food";probabilistic=true)
    select_probe!(loop,1)
    LW.resolve_method!(loop,1,true,false;method_forecast=evidence)
    @test loop.methods["approach"].H==0. && loop.H==0.
    select_probe!(loop,2)
    LW.resolve_method!(loop,2,false,false;method_forecast=LW.navigation_forecast_result(forecast,nothing,[target(10)]))
    @test loop.methods["approach"].H==1. && loop.H==0.
    select_probe!(loop,3)
    LW.resolve_method!(loop,3,true,false;method_forecast=(1.,1.))
    @test loop.methods["approach"].H==1. # Matching one step does not erase old difference.
    select_probe!(loop,4)
    LW.resolve_method!(loop,4,true,false;method_forecast=(1.,2.))
    @test loop.methods["approach"].H==0.
    @test !LW.resolve_method!(loop,4,true,false;method_forecast=(1.,2.))
    @test LW.navigation_forecast_result(forecast,nothing,[target(10)];sensitivity=.5)==(.5,0.)
    short=LW.navigation_forecast(merge(plan,D("approach_span"=>.2)),move,target(10),"home")
    @test short["scale"]==.2
    @test LW.navigation_forecast_result(short,target(9.8),Any[])[1]≈1.
    stats=D();LW.navigation_forecast_record!(stats,forecast,nothing)
    LW.navigation_forecast_record!(stats,forecast,(1.,0.))
    @test stats["navigation_forecast_stats"]["unobserved"]==1
    @test stats["navigation_forecast_stats"]["evaluated"]==1
end
@testset "exploration discovery uses the same ledger" begin
    map=LW.mb_map_state(first(LW.IDS))
    LW.acquisition_result!(map,"explore",nothing,100.,200.,false;now=1)
    @test map["acquisition"]["methods"]["explore"]["H"]==2.
    @test LW.acquisition_observe!(map,[D("ref"=>1,"acquisition"=>"pickup")])
    @test map["acquisition"]["methods"]["explore"]["H"]==1.
    @test get(map["acquisition"]["methods"],"pickup",nothing)===nothing
    @test !LW.acquisition_observe!(map,[D("ref"=>1,"acquisition"=>"pickup")])
    io=IOBuffer();serialize(io,map);seekstart(io);restored=deserialize(io)
    @test restored["acquisition"]==map["acquisition"]
end
