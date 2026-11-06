using Test, Serialization
include("../../src/lw/LW.jl")
const ids=LW.IDS
const A,B=ids[1:2]
function expiry_fixture()
 w=LW.world(true);empty!(w.obstacles)
 for a in ids;w.positions[a]=(0.,0.);w.inventory[a]=0;end
 w.inventory[A]=3
 stores=Dict(a=>0 for a in ids);stores[A]=3
 spec=(typed_food=true,initial_inventory_kinds=[a==A ? [5,2,5] : Int[] for a in ids],
       initial_personal_food_counts=Dict(Symbol(a)=>(a==A ? [1,0,0,0,2] : zeros(Int,5)) for a in ids),initial_shared_food_counts=[0,0,0,0,1])
 food=Any[(x=0.,z=1.,stock=20,food_kind=5,appearance="fishing_water",acquisition="fishing",renewable=false)]
 stock=[20];r=LW.food_resources(spec,w,food,stock,1,stores)
 cargo=Dict(a=>Any[nothing for _ in 1:w.inventory[a]] for a in ids)
 (w=w,r=r,food=food,stock=stock,stores=stores,cargo=cargo)
end
@testset "fish deadline survives all custody changes" begin
 f=expiry_fixture();r=f.r;w=f.w
 # Gift one fish, deposit it, exchange a stored fish for the other owner's fish.
 LW.food_give!(r,A,B,1);w.inventory[A]-=1;w.inventory[B]+=1;popfirst!(f.cargo[A]);push!(f.cargo[B],nothing)
 LW.food_deposit!(r,B,false);f.stores[B]+=w.inventory[B];w.inventory[B]=0;empty!(f.cargo[B])
 trade=LW.food_exchange_state()
 @test LW.food_exchange_execute!(trade,r,w,f.stores,(0.,0.),A,"offer","trade_offer",0;target=B,give_kind=1,give_count=1,want_kind=5,want_count=1)["status"]=="offered"
 offer=only(keys(trade["offers"]))
 @test LW.food_exchange_execute!(trade,r,w,f.stores,(0.,0.),B,"accept","trade_accept",1;offer_id=offer)["status"]=="exchanged"
 LW.food_retrieve!(r,A,false,nothing,80.;kind=5);f.stores[A]-=1;w.inventory[A]+=1;push!(f.cargo[A],nothing)
 LW.food_give!(r,A,B,length(r.inventory[A]));w.inventory[A]-=1;w.inventory[B]+=1;pop!(f.cargo[A]);push!(f.cargo[B],nothing)
 # Drop the retrieved fish; it too expires, unlike living fish in water.
 g=LW.cargo_ground();status=LW.cargo_transfer!(g,w,f.cargo,f.food,f.stock,B,"drop",2,"drop")
 LW.food_track_cargo!(r,g,f.food,B,"drop","drop",status,0)
 @test LW.food_expire_fish!(r,w,f.cargo,f.food,f.stock,f.stores,1,0)==1
 @test r.game.expired_fish==0
 io=IOBuffer();serialize(io,f);seekstart(io);restored=deserialize(io)
 for x in (f,restored)
  shared=LW.food_expire_fish!(x.r,x.w,x.cargo,x.food,x.stock,x.stores,1,1)
  @test shared==1
  @test x.r.game.expired_fish==5
  @test x.r.inventory[A]==[2,6] # ordinary meat unchanged
  @test x.stock==[20,1] && x.r.site_kinds[2]==6
  @test LW.food_audit!(x.r,x.w,x.stock,shared,x.stores)===nothing
  @test LW.food_expire_fish!(x.r,x.w,x.cargo,x.food,x.stock,x.stores,1,1)==1
  @test x.r.game.expired_fish==5
  @test LW.food_meal_index(x.r,A,nothing,80.,5)==0
 end
 # A newly caught fish on the new day survives until the next boundary.
 r.game.fishing["seed"]=1
 for t in 0:3599;LW.fishing_tick!(r,w,f.cargo,f.food,f.stock,A,1,1_000_000_000+t*1_000_000,"new:$t");end
 caught=r.game.fishing[A]["caught"]
 @test caught>0
 LW.food_expire_fish!(r,w,f.cargo,f.food,f.stock,f.stores,1,1)
 @test count(==(5),r.inventory[A])==caught
 LW.food_expire_fish!(r,w,f.cargo,f.food,f.stock,f.stores,1,2)
 @test r.game.expired_fish==5+caught
 @test LW.food_audit!(r,w,f.stock,1,f.stores)===nothing
end
@testset "salt observation is taste, not nutrition or a recipe" begin
 f=expiry_fixture();m=LW.D()
 s=LW.portable_items((loose_items=[(id=1,kind=4,x=0.,z=0.,location="stored",owner=A),(id=2,kind=4,x=3.,z=3.)],),f.w)
 @test LW.item_taste!(s,m,f.w,(0.,0.),B,1,0)=="taste_unavailable"
 @test LW.item_taste!(s,m,f.w,(0.,0.),A,2,0)=="taste_unavailable"
 before=LW.item_snapshot(s)
 @test LW.item_taste!(s,m,f.w,(0.,0.),A,1,0)=="tasted"
 @test LW.item_taste!(s,m,f.w,(0.,0.),A,1,0)=="tasted"
 experience=only(values(m["item_taste_experiences"]))
 @test experience["samples"]==1 && experience["salinity"]==1
 @test experience["features"]["color"]=="white"
 @test LW.item_snapshot(s)==before
 @test f.w.consumed==0
 q=LW.configured_fishing_training_state(;salt=true)
 LW.configured_fishing_training_result!(q,"eat","ate",7,true,0;liking=.75)
 @test q["stage"]=="salt"
 @test LW.configured_fishing_training_plan(q,[],true,true,[];items=s,actor=A)["action"]=="taste_item"
 LW.configured_fishing_training_result!(q,"taste_item","taste_unavailable",0,true,1)
 @test q["stage"]=="salt"
 LW.configured_fishing_training_result!(q,"taste_item","tasted",0,true,2)
 @test q["stage"]=="trial"
end

@testset "fish quantities participate in exchange learning" begin
 memory=Any[]
 give=LW.D("items"=>Any[],"food"=>[0,0,0,0,1,0])
 want=LW.D("items"=>Any[],"food"=>[1,0,0,0,0,0])
 learned=LW.item_exchange_accumulate!(memory,give,want,B,0.,1,0,0)
 @test length(learned["quantity_coefficients"])==14
 @test isfinite(LW.item_exchange_response(learned,give,want))
end
