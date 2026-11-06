include("checks.jl")
using Random
include("river_scene.jl")
@testset "river spatial depletion and shared conservation" begin
 site(x;river="r",p=.05,n=4)=(x=Float64(x),z=1.,stock=n,food_kind=5,appearance="river_water",acquisition="fishing",renewable=false,river_id=river,fishing_base_probability=p,fishing_radius=4.)
 food=[site(0),site(2),site(20),site(1;river="other")]; stock=[4,4,4,4]
 @test LW.validate_river_fishing(food)===nothing
 before=[LW.river_fishing_field(food,stock,i,0.).probability for i in 1:4]
 stock[1]-=1
 after=[LW.river_fishing_field(food,stock,i,0.).probability for i in 1:4]
 @test after[1]<before[1] && after[2]<before[2]
 @test after[3:4]==before[3:4]
 stock[1]=0
 field=LW.river_fishing_field(food,stock,1,0.)
 @test field.probability>0
 @test LW.river_fishing_take!(stock,field.neighbors,MersenneTwister(1))==2
 @test stock==[0,3,4,4]
 for _ in 1:3;LW.river_fishing_take!(stock,field.neighbors,MersenneTwister(1));end
 @test LW.river_fishing_field(food,stock,1,0.).probability==0
 @test LW.river_fishing_take!(stock,field.neighbors,MersenneTwister(1))===nothing
 @test all(>=(0),stock)
 @test_throws ErrorException LW.validate_river_fishing([site(0;p=2.)])
 # Actual casting uses the shared ledger, and checkpoint continuation is exact.
 f=fixture(;stock=1); f=merge(f,(food=[site(0;p=1.,n=1)],))
 for t in 0:89;tick(f,t);end
 io=IOBuffer();serialize(io,f);seekstart(io);g=deserialize(io)
 @test [tick(f,t) for t in 90:539]==[tick(g,t) for t in 90:539]
 @test f.stock==[0] && f.w.inventory[A]==1
 @test audit(f)===nothing
 @test LW.fishing_snapshot(f.r)==LW.fishing_snapshot(g.r)
 @test tick(f,539)=="no_catch" && f.w.inventory[A]==1
 full=fixture(); empty=fixture(;stock=0)
 full=merge(full,(food=[site(0;p=.9,n=20)],));empty=merge(empty,(food=[site(0;p=.01,n=20)],))
 obs(f)=LW.perceive_movement(f.w,A,Dict(a=>0. for a in LW.IDS),f.food,f.stock).visible
 @test obs(full)==obs(empty)
 a=obs(full);b=obs(empty);LW.fishing_observation!(full.r,A,a);LW.fishing_observation!(empty.r,A,b)
 @test a==b
 @test LW.game_fishing_forecast(LW.D(),LW.D("recent"=>fill(false,32),"caught"=>100,"attempts"=>132)).probability < LW.game_fishing_forecast(LW.D(),LW.D("recent"=>fill(true,32))).probability
end
@testset "river fixture finite and mostly difficult" begin
 s=Dict("landscape"=>Dict("phase"=>0.),"obstacles"=>Any[],"food"=>Any[])
 meta=add_river_fishing!(s)
 @test meta["total_stock"]==240
 @test count(<=(.05),meta["base_probabilities"])>meta["sites"]/2
 @test all(f->!f["renewable"],s["food"])
end
