using Test, Serialization
include("../../src/lw/LW.jl")
const A=LW.IDS[1];const B=LW.IDS[2]
@testset "unharvested supply waits; dropping and recovery do not renew food" begin
 w=LW.world(true);empty!(w.obstacles);stores=Dict(a=>0 for a in LW.IDS)
 for a in LW.IDS;w.inventory[a]=0;w.positions[a]=(0.,0.);end
 food=Any[(x=0.,z=1.,stock=2,food_kind=1,appearance="red_round_fruit")];stock=[2]
 r=LW.food_resources((typed_food=true,food_batch_expiry=true,),w,food,stock,0,stores)
 LW.food_expire_batches!(r,food,stock,0,60)
 @test r.site_kinds==[1] && stock==[2] && isempty(r.game.expired_by_kind)
 @test LW.food_acquisition_deadline(r,1)==65
 stock[1]-=1;w.inventory[A]+=1
 LW.food_push!(r,A,1;deadline=LW.food_acquisition_deadline(r,1))
 cargo=Dict(a=>(a==A ? Any["harvest"] : Any[]) for a in LW.IDS);dropped=LW.cargo_ground()
 status=LW.cargo_transfer!(dropped,w,cargo,food,stock,A,"drop",1,"drop")
 LW.food_track_cargo!(r,dropped,food,A,"drop","drop",status,0)
 @test status=="dropped" && r.game.age.sites[2]==65
 LW.food_expire_batches!(r,food,stock,0,64)
 status=LW.cargo_transfer!(dropped,w,cargo,food,stock,A,"recover",2,"recover";index=2)
 LW.food_track_cargo!(r,dropped,food,A,"recover","recover",status,2)
 @test status=="recovered" && LW.food_inventory_deadline(r,A,1)==65
 LW.food_expire_batches!(r,food,stock,0,65)
 @test r.inventory[A]==[6] && r.site_kinds[1]==1 && stock[1]==1
 @test r.game.expired_by_kind[1]==1
 @test LW.food_audit!(r,w,stock,0,stores)===nothing
 @test LW.food_age_audit!(r)===nothing
end
function age_fixture()
 w=LW.world(true);stores=Dict(a=>0 for a in LW.IDS)
 for a in LW.IDS;w.inventory[a]=0;end
 r=LW.food_resources((typed_food=true,food_batch_expiry=true,),w,Any[],Int[],0,stores)
 (r=r,w=w,stores=stores)
end
@testset "batches keep dates across transfers and only expire due stock" begin
 f=age_fixture();r=f.r
 LW.food_push!(r,A,1);r.initial[1]+=1;f.w.inventory[A]=1
 LW.food_deposit!(r,A,false);f.w.inventory[A]=0;f.stores[A]=1
 LW.food_expire_batches!(r,Any[],Int[],0,1)
 LW.food_push!(r,A,1,3);r.initial[1]+=1;f.w.inventory[A]=1
 LW.food_deposit!(r,A,false);f.w.inventory[A]=0;f.stores[A]+=1
 @test Set(keys(r.game.age.stores[A]))==Set([(1,2,5),(1,3,6)])
 give=zeros(Int,8);give[1]=1;want=zeros(Int,8)
 LW.food_quality_swap!(r,A,B,give,want)
 r.personal[A].-=give;r.personal[B].+=give;f.stores[A]-=1;f.stores[B]+=1
 @test haskey(r.game.age.stores[B],(1,2,5))
 LW.food_retrieve!(r,B,false,nothing,80.;kind=1);f.stores[B]-=1;f.w.inventory[B]+=1
 @test LW.food_inventory_deadline(r,B,1)==5
 LW.food_give!(r,B,A);f.w.inventory[B]-=1;f.w.inventory[A]+=1
 @test LW.food_inventory_deadline(r,A,1)==5
 LW.food_expire_batches!(r,Any[],Int[],0,5)
 @test r.inventory[A]==[6] && r.personal[A][1]==1
 @test r.game.expired_fish==0 && r.game.expired_by_kind[1]==1
 @test LW.food_age_audit!(r)===nothing
 @test LW.food_audit!(r,f.w,Int[],0,f.stores)===nothing
 LW.food_expire_batches!(r,Any[],Int[],0,5)
 @test r.game.expired_by_kind[1]==1
 LW.food_expire_batches!(r,Any[],Int[],0,6)
 @test r.personal[A][6]==1 && r.personal[A][1]==0
 @test LW.food_audit!(r,f.w,Int[],0,f.stores)===nothing
 io=IOBuffer();serialize(io,r);seekstart(io);restored=deserialize(io)
 @test LW.food_age_snapshot(restored)==LW.food_age_snapshot(r)
end
@testset "appearance hides exact deadlines and affects subjective retention" begin
 f=age_fixture();r=f.r;m=LW.mb_map_state(A);day=17_280_000_000
 LW.food_push!(r,A,1);r.initial[1]+=1;f.w.inventory[A]=1
 view=only(LW.food_condition_visuals(r,A,false))
 @test view["condition"]==0 && !haskey(view,"deadline")
 LW.food_condition_observe!(m,r.inventory[A],r.personal[A],true,0,day;foods=r,actor=A)
 fresh=LW.food_storage_survival(m,1,1)
 LW.food_expire_batches!(r,Any[],Int[],0,2)
 @test only(LW.food_condition_visuals(r,A,false))["condition"]==1
 LW.food_condition_observe!(m,r.inventory[A],r.personal[A],true,2day,day;foods=r,actor=A)
 @test LW.food_storage_survival(m,1,1)<fresh
 @test !occursin("deadline",repr(m["food_conditions"]["visible_batches"]))
 LW.food_expire_batches!(r,Any[],Int[],0,5)
 LW.food_condition_observe!(m,r.inventory[A],r.personal[A],true,5day,day;foods=r,actor=A)
 @test m["food_conditions"]["storage"]["1"]["cue_failures"]["1"]==1
 for k in (2,3,4,5,7,8)
  g=age_fixture();LW.food_push!(g.r,A,k);g.r.initial[k]+=1;g.w.inventory[A]=1
  lifetime=LW.FOOD_LIFETIME_DAYS[k]
  LW.food_expire_batches!(g.r,Any[],Int[],0,lifetime)
  @test g.r.inventory[A]==[6]
  @test LW.food_audit!(g.r,g.w,Int[],0,g.stores)===nothing
 end
end
@testset "processing creates product batch and discarding removes its lot" begin
 f=age_fixture();r=f.r
 LW.food_push!(r,A,3);r.initial[3]=1;f.w.inventory[A]=1
 LW.food_expire_batches!(r,Any[],Int[],0,2)
 for i in 1:120;LW.food_process!(r,A;kind=3);end
 @test r.inventory[A]==[4] && LW.food_inventory_deadline(r,A,1)==12
 @test LW.food_audit!(r,f.w,Int[],0,f.stores)===nothing
 LW.food_deposit!(r,A,false);f.w.inventory[A]=0;f.stores[A]=1
 f.w.positions[A]=(0.,0.)
 bin=(id=2,x=0.,z=0.,work_radius=2.,accepts_waste=true)
 cargo=Dict(a=>Any[] for a in LW.IDS)
 q=only(keys(r.game.age.stores[A]))[2]
 @test LW.food_discard!(r,f.w,cargo,f.stores,[bin],A,4,q,true,false,"discard",1)=="discarded"
 @test isempty(r.game.age.stores[A])
 @test LW.food_age_audit!(r)===nothing
 @test LW.food_audit!(r,f.w,Int[],0,f.stores)===nothing
end
