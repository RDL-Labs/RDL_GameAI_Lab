using Test
D(args...)=Dict{String,Any}(args...)
item_contact(w,a,b)=w
include("../../src/lw/configured_paths/trade_idle.jl")
@testset "configured trade suspension and notification wake" begin
 m=D();state=D("social"=>D("pending"=>nothing,"next_us"=>0));items=D("offers"=>D())
 view=D("incoming"=>Any[],"outgoing"=>nothing)
 @test !configured_trade_idle_ready!(m,state,items,true,"a",0,100_000_000)
 configured_trade_idle_considered!(m,state,view,nothing,1,100_000_000)
 @test !m["configured_trade_idle"]["ready"] # skipped cooldown is not a decision
 state["social"]["next_us"]=64_000_001
 configured_trade_idle_considered!(m,state,view,nothing,1,100_000_000)
 @test configured_trade_idle_ready!(m,state,items,true,"a",2,100_000_000)
 items["offers"]["x"]=D("target"=>"a","proposer"=>"b","expires_us"=>20)
 @test configured_trade_idle_ready!(m,state,items,false,"a",3,100_000_000)
 @test !configured_trade_idle_ready!(m,state,items,true,"a",3,100_000_000)
 @test m["configured_trade_idle"]["wakeups"]==1
 empty!(items["offers"])
 configured_trade_idle_considered!(m,state,view,nothing,21,100_000_000;allow_start=false)
 @test configured_trade_idle_ready!(m,state,items,true,"a",22,100_000_000)
 state["social"]["pending"]=D("offer_id"=>"x")
 @test !configured_trade_idle_ready!(m,state,items,true,"a",23,100_000_000)
 state["social"]["pending"]=nothing
 configured_trade_idle_considered!(m,state,view,D("action"=>"item_decline"),24,100_000_000;allow_start=false)
 @test !m["configured_trade_idle"]["ready"]
 configured_trade_idle_considered!(m,state,view,nothing,25,100_000_000;allow_start=false)
 @test !configured_trade_idle_ready!(m,state,items,true,"a",100_000_000,100_000_000)
end
@testset "social notification wakes return-idle" begin
 w=(seconds=10,inbox=D("a"=>[D("id"=>"m","time"=>9,"kind"=>"request")]))
 @test configured_social_notice(w,"a",Set{String}())
 @test !configured_social_notice(w,"a",Set(["m"]))
 @test !configured_social_notice((seconds=12,inbox=w.inbox),"a",Set{String}())
 m=D();state=D("social"=>D("pending"=>nothing,"next_us"=>0));items=D("offers"=>D())
 configured_trade_idle_ready!(m,state,items,true,"a",0,1000)
 m["configured_trade_idle"]["ready"]=true
 @test !configured_trade_idle_ready!(m,state,items,true,"a",1,1000;social_notice=true)
 @test m["configured_trade_idle"]["wakeups"]==1
end
