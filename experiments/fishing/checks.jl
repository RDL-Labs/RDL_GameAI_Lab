using Test, Serialization
include("../../src/lw/LW.jl")
const A=first(LW.IDS)
function fixture(;stock=20,seed=1)
    w=LW.world(true);empty!(w.obstacles)
    for a in LW.IDS;w.inventory[a]=0;w.positions[a]=(0.,0.);end
    food=[(x=0.,z=1.,stock=stock,food_kind=5,appearance="fishing_water",acquisition="fishing",renewable=false)]
    stores=Dict(a=>0 for a in LW.IDS);counts=[stock]
    r=LW.food_resources((typed_food=true,),w,food,counts,0,stores);r.game.fishing["seed"]=seed
    cargo=Dict(a=>Any[] for a in LW.IDS)
    (w=w,r=r,food=food,stock=counts,stores=stores,cargo=cargo)
end
tick(f,t)=LW.fishing_tick!(f.r,f.w,f.cargo,f.food,f.stock,A,1,t*1_000_000,"op:$t")
audit(f)=LW.food_audit!(f.r,f.w,f.stock,0,f.stores)
@testset "fishing rules retain large uncertainty" begin
    @test LW.game_fishing_probability(0.)==.25
    @test LW.game_fishing_probability(3.)==.45
    @test LW.game_fishing_probability(100.)==.45
    @test LW.game_fishing_forecast(LW.D(),LW.D()).seconds==720.
    @test LW.game_fishing_forecast(LW.D(),LW.D("caught"=>0,"attempts"=>10)).probability<.25
end
@testset "water appearance does not reveal fish stock" begin
    full=fixture();empty=fixture(;stock=0)
    obs(f)=LW.perceive_movement(f.w,A,Dict(a=>0. for a in LW.IDS),f.food,f.stock;known_food_sites=[0])
    @test obs(full).visible==obs(empty).visible
    @test isempty(obs(empty).empty_sites)
    @test only(obs(full).visible)["acquisition"]=="fishing"
    full.w.positions[A]=(0.,-30.)
    @test isempty(obs(full).visible)
    @test tick(full,0)=="fishing_unavailable"
    @test isempty(full.r.game.skills)
end
@testset "completed trials, misses, interruption and replay" begin
    f=fixture(;stock=0)
    for t in 0:178;@test tick(f,t)=="fishing";end
    @test isempty(f.r.game.skills)
    @test tick(f,179)=="no_catch"
    @test f.r.game.skills[A]["fishing"]["experience"]==1
    @test audit(f)===nothing
    @test tick(f,179)=="no_catch"
    @test f.r.game.skills[A]["fishing"]["experience"]==1
    @test_throws ErrorException LW.fishing_tick!(f.r,f.w,f.cargo,f.food,f.stock,A,1,179_000_000,"different")
    @test tick(f,180)=="fishing"
    LW.fishing_cancel!(f.r,A,181_000_000,"rest")
    @test f.r.game.skills[A]["fishing"]["experience"]==1
    @test tick(f,182)=="fishing"
    @test f.r.game.fishing[A]["active"]["ticks"]==1
end
@testset "finite catches, deterministic continuation, and acquisition evidence" begin
    f=fixture(;stock=1)
    for t in 0:89;tick(f,t);end
    io=IOBuffer();serialize(io,f);seekstart(io);g=deserialize(io)
    left=[tick(f,t) for t in 90:3599];right=[tick(g,t) for t in 90:3599]
    @test left==right
    @test count(==("picked_up"),left)==1
    @test f.stock==[0] && f.w.inventory[A]==1 && f.r.inventory[A]==[5]
    @test f.r.game.skills[A]["fishing"]["completed"]==20
    @test audit(f)===nothing && audit(g)===nothing
    @test LW.fishing_snapshot(f.r)==LW.fishing_snapshot(g.r)
    # A second actor cannot take the same final fish.
    other=LW.IDS[2]
    for t in 0:179;LW.fishing_tick!(f.r,f.w,f.cargo,f.food,f.stock,other,1,t*1_000_000,"other:$t");end
    @test f.w.inventory[other]==0 && audit(f)===nothing
    m=LW.mb_map_state(A);m["daily_plan"]=LW.mb_daily_plan_state(A,1)
    visible=LW.perceive_movement(f.w,A,Dict(a=>0. for a in LW.IDS),f.food,f.stock).visible
    LW.fishing_observation!(f.r,A,visible)
    e=LW.mb_daily_evidence(m,LW.D("visible"=>visible),70.,0.,0)
    @test e["source"]=="fishing_spot" && e["seconds"]>180
    @test !haskey(only(visible),"stock")
end
