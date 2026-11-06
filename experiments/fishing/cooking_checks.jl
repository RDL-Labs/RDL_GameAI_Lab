include("checks.jl")
@testset "fish requires cooking, recipe and conservation" begin
 @test !LW.RDLBody.food_edible(5)
 @test LW.RDLBody.food_edible(7)
 @test_throws ErrorException LW.RDLBody.ingest!(LW.RDLBody.Digestion(),5,50.,0)
 f=fixture(;stock=0)
 LW.food_push!(f.r,A,5);f.w.inventory[A]=1;f.r.initial[5]+=1;push!(f.cargo[A],"sample")
 q=LW.configured_fishing_training_state()
 @test LW.configured_fishing_training_plan(q,[5],true,true,Any[])["action"]=="process_food"
 for _ in 1:119;@test LW.food_process!(f.r,A;kind=5)=="processing";end
 @test LW.food_process!(f.r,A;kind=5)=="processed"
 @test f.r.inventory[A]==[7]
 @test f.r.game.skills[A]["fish_cooking"]["completed"]==1
 @test audit(f)===nothing
 @test LW.configured_fishing_training_plan(q,[7],true,true,Any[])["action"]=="eat"
 LW.configured_fishing_training_result!(q,"eat","ate",7,true,0)
 @test q["stage"]=="trial"
 facilities=[(id=1,x=0.,z=0.,work_radius=2.,height=1.,radius=.5,color="orange",processing_kinds=[5])]
 @test LW.food_facility_for(facilities,(0.,0.),5)!==nothing
 @test LW.food_facility_for(facilities,(10.,0.),5)===nothing
 LW.food_expire_fish!(f.r,f.w,f.cargo,f.food,f.stock,f.stores,0,1)
 @test f.r.inventory[A]==[6] && f.r.game.expired_by_kind[7]==1
 @test audit(f)===nothing
 # Multiple ingredients: requested fish must not accidentally process an acorn.
 LW.food_push!(f.r,A,3);LW.food_push!(f.r,A,5)
 for _ in 1:120;LW.food_process!(f.r,A;kind=5);end
 @test f.r.inventory[A]==[6,3,7]
 m=LW.D();LW.food_condition_observe!(m,[7],zeros(Int,7),false,0,1000000)
 LW.food_condition_observe!(m,[6],zeros(Int,7),false,1000000,1000000)
 LW.food_condition_result!(m,6,false,1000000)
 @test m["food_conditions"]["storage"]["7"]["unusable_episodes"]==1
end
@testset "placed rock salt turns one fish into salt grilled fish" begin
 f=fixture(;stock=0); m=LW.D()
 items=LW.portable_items((loose_items=[(id=1,kind=4,x=0.,z=0.)],),f.w)
 take=LW.item_execute!(items,f.r,f.w,f.stores,(0.,0.),A,"get-salt","item_pickup",0;item_id=1)
 @test take["status"]=="picked_up"
 @test LW.item_taste!(items,m,f.w,(0.,0.),A,1,1)=="tasted"
 LW.food_push!(f.r,A,5);f.r.initial[5]+=1;f.w.inventory[A]+=1;push!(f.cargo[A],"fish")
 facility=(x=0.,z=0.,processing_kinds=[5],work_radius=2.)
 choices=LW.food_desire_candidates(m,f.r,A,nothing,80.,true,f.r.personal[A],[facility],(0.,0.);items)
 @test any(c->get(c,"food_kind",0)==8 && c["salt_id"]==1,choices)
 for t in 1:120;LW.food_process!(f.r,A;kind=5,salt_id=1,items,now=t);end
 @test f.r.inventory[A]==[8] && f.r.game.salted_fish==1
 @test items["items"][1]["location"]==LW.ITEM_CONSUMED
 @test LW.food_process!(f.r,A;kind=5,salt_id=1,items)=="preparation_unavailable"
 @test audit(f)===nothing && LW.item_audit!(items,f.w)===nothing
 LW.food_expire_fish!(f.r,f.w,f.cargo,f.food,f.stock,f.stores,0,1)
 @test f.r.inventory[A]==[6] && audit(f)===nothing
end
@testset "salted fish tasting and appearance only" begin
 f=fixture(); items=LW.portable_items((loose_items=[(id=1,kind=4,x=8.,z=12.)],),f.w)
 m=LW.D();q=LW.configured_fishing_training_state(visual=true)
 @test LW.configured_fishing_training_plan(q,[8],true,true,Any[])["action"]=="eat"
 LW.configured_fishing_training_result!(q,"eat","ate",8,true,0;liking=1.)
 @test LW.configured_fishing_training_plan(q,[],true,true,Any[])["action"]=="observe_salt_sample"
 status=LW.configured_observe_salt_sample!(m,items)
 LW.configured_fishing_training_result!(q,"observe_salt_sample",status,0,true,1)
 @test q["stage"]=="trial" && LW.recognized_salt(m,items["items"][1])
 @test !haskey(m,"item_taste_experiences") && items["items"][1]["owner"]===nothing
end
