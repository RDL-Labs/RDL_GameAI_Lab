using Test, JSON3
include("../../src/lw/LW.jl")
@testset "renewal preserves harvested expiry and accounting" begin
 w=LW.world(true);stores=Dict(a=>0 for a in LW.IDS)
 for a in LW.IDS;w.inventory[a]=0;end
 food=Any[(x=0.,z=1.,stock=3,food_kind=1,renewable=true),
  (x=1.,z=1.,stock=3,food_kind=5,renewable=true,acquisition="fishing")]
 stock=[3,3];a=first(LW.IDS)
 r=LW.food_resources((typed_food=true,food_batch_expiry=true,),w,food,stock,0,stores)
 for (j,k) in ((1,1),(2,5))
  stock[j]-=1;LW.food_push!(r,a,k;deadline=LW.food_acquisition_deadline(r,j));w.inventory[a]+=1
 end
 season=LW.seasonal_food_config((food_season=(period_days=60,low_rate=1.,high_rate=1.),),true,1)
 old=copy(stock);@test LW.seasonal_replenish_food!(stock,food,season,1)==2
 for j in eachindex(stock);r.added[r.site_kinds[j]]+=stock[j]-old[j];end
 @test stock==[3,3]
 LW.food_expire_batches!(r,food,stock,0,1)
 @test r.inventory[a]==[1,6]
 @test stock==[3,3] && r.site_kinds==[1,5]
 @test LW.food_audit!(r,w,stock,0,stores)===nothing
 @test LW.food_age_audit!(r)===nothing
 LW.food_expire_batches!(r,food,stock,0,5)
 @test r.inventory[a]==[6,6] && stock==[3,3]
 @test LW.food_audit!(r,w,stock,0,stores)===nothing
end
@testset "renewal and batch expiry integrated resume" begin
 clock=merge(LW.native_clock(),(day_us=96_000_000,phase_boundaries_us=fill(96_000_000,4),quiet_night_us=96_000_000))
 scene=merge(LW.native_scene(19),(positions=[[0.,0.],[0.,.75],[1.,0.]],home=[0.,0.],
  food=Any[(x=0.,z=0.,stock=3,renewable=true,food_kind=1),
   (x=0.,z=1.,stock=3,renewable=true,food_kind=5,acquisition="fishing",appearance="river_water")],
  obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],reserve=[30.,30.,30.],
  typed_food=true,food_batch_expiry=true,food_season=(period_days=4,low_rate=.02,high_rate=.8)))
 # Explicit spare capacity guarantees this fixture exercises replenishment,
 # independently of whether its short-lived actors choose to harvest.
 trial(;kwargs...)=LW.lw_day(scene,clock;days=6,basic_loop=true,food_body=true,mb_simulation=true,landmark_routes=true,renewable_food=true,regrowth_capacity=6,choice_seed=3,kwargs...)
 mktempdir() do dir
  r=trial(checkpoint_dir=dir,checkpoint_identity="expiry-regrowth")
  resumed=trial(resume_from=joinpath(dir,"day-003.jls"),checkpoint_identity="expiry-regrowth")
  @test JSON3.read(JSON3.write(r))==JSON3.read(JSON3.write(resumed))
  @test r["replenished_food"]>0
  @test sum(r["food_resources"]["added"])==r["replenished_food"]
 end
end
