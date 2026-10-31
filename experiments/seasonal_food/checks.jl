using Test, JSON3
include("../../src/lw/LW.jl")
@testset "seasonal finite capacity and fractional supply" begin
    spec=(food_season=(period_days=60,low_rate=.25/42,high_rate=5/42),)
    s=LW.seasonal_food_config(spec,true,1)
    food=[(stock=42,renewable=true),(stock=8,renewable=false)]
    stock=[0,8,7];daily=Int[]
    for day in 1:180
        stock[1]=0
        push!(daily,LW.seasonal_replenish_food!(stock,food,s,day))
        @test stock[2:3]==[8,7] # Finite provisions and dropped cargo never grow.
    end
    @test sum(daily) in (472,473)
    @test sum(daily[1:10])>sum(daily[26:35])
    @test sum(daily[61:120])≈sum(daily[1:60]) atol=1
    stock=[50,8,7]
    @test LW.seasonal_replenish_food!(stock,food,s,1)==0
    @test stock==[50,8,7] # Lower capacity/season does not erase existing food.
    stock=[41,8,7]
    @test LW.seasonal_replenish_food!(stock,food,s,1)==1
    @test stock[1]==42
    @test LW.seasonal_food_config((;),false,3)===nothing
    @test_throws ErrorException LW.seasonal_food_config(spec,false,1)
    @test_throws ErrorException LW.seasonal_food_config(spec,true,3)
    @test_throws ErrorException LW.seasonal_food_config((food_season=(period_days=0,),),true,1)
    legacy=[0,8,7];@test LW.replenish_food!(legacy,food)==42
end
@testset "seasonal world accounting and daily resume" begin
    clock=merge(LW.native_clock(),(day_us=96_000_000,phase_boundaries_us=[96_000_000,96_000_000,96_000_000,96_000_000],quiet_night_us=96_000_000))
    scene=merge(LW.native_scene(19),(positions=[[0.,0.],[0.,.75],[1.,0.]],home=[0.,0.],
        food=Any[(x=0.,z=0.,stock=3,renewable=true,food_kind=1)],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        reserve=[30.,30.,30.],typed_food=true,food_season=(period_days=4,low_rate=.02,high_rate=.8)))
    run(;kwargs...)=LW.lw_day(scene,clock;days=6,basic_loop=true,food_body=true,renewable_food=true,regrowth_capacity=6,choice_seed=3,kwargs...)
    mktempdir() do dir
        r=run(checkpoint_dir=dir,checkpoint_identity="seasonal")
        resumed=run(resume_from=joinpath(dir,"day-003.jls"),checkpoint_identity="seasonal")
        @test JSON3.read(JSON3.write(r))==JSON3.read(JSON3.write(resumed))
        @test r["replenished_food"]>0
        @test sum(r["food_resources"]["added"])==r["replenished_food"]
        for d in r["daily"]
            @test r["initial_food"]+d["replenished_food"]==d["ground"]+d["shared_stock"]+d["consumed"]+sum(p["inventory"]+p["personal_stock"] for p in values(d["physical"]))
        end
    end
    fastclock=merge(clock,(day_us=1_000_000,phase_boundaries_us=fill(1_000_000,4),quiet_night_us=1_000_000))
    @test length(LW.lw_day(scene,fastclock;days=180,renewable_food=true)["daily"])==180
    @test_throws ErrorException LW.lw_day(scene,fastclock;days=181,renewable_food=true)
end
