using Test
include("../../src/lw/LW.jl")
const A=first(LW.IDS)
@testset "visible change plus rejection teaches storage, not hidden expiry" begin
 day=17_280_000_000
 m=LW.mb_map_state(A)
 fresh=[0,0,0,0,8,0,0,0];changed=[0,0,0,0,0,8,0,0]
 LW.food_condition_observe!(m,Int[],fresh,true,0,day)
 @test LW.food_storage_survival(m,5,1)==.5
 LW.food_condition_observe!(m,Int[],changed,false,day,day)
 @test isempty(m["food_conditions"]["pending"])
 LW.food_condition_observe!(m,Int[],changed,true,day+64_000_000,day)
 @test length(m["food_conditions"]["pending"])==1
 @test LW.food_storage_survival(m,5,1)==.25 # observed loss updates the hypothesis before tasting
 LW.food_condition_result!(m,6,false,day+65_000_000)
 @test LW.food_condition_usable(m,6)==0
 @test LW.food_storage_survival(m,5,0)==1
 @test LW.food_storage_survival(m,5,1)==.25 # checking does not count the same episode twice
 for t in 66:130;LW.food_condition_observe!(m,Int[],changed,true,day+t*1_000_000,day);end
 LW.food_condition_result!(m,6,false,day+131_000_000)
 @test m["food_conditions"]["storage"]["5"]["unusable_episodes"]==1
 @test LW.food_storage_survival(m,2,1)==.7 # unrelated kind retains its own initial estimate
 # Existing forecast uses experience only for the surplus beyond today's needs.
 body=LW.Body(10.,0.,80.,0.)
 unlearned=LW.mb_map_state(A)
 a=LW.food_security_state();b=LW.food_security_state()
 LW.food_security_update!(a,unlearned,body,nothing,fresh,Int[],0.,0,day)
 LW.food_security_update!(b,m,body,nothing,fresh,Int[],0.,0,day)
 @test b["supplied"]<a["supplied"]
 LW.food_security_update!(b,m,body,nothing,changed,[6],0.,1,day)
 @test b["supplied"]==0
end
@testset "unknown changed material competes for checking; rejection lowers weight" begin
 w=LW.world(true);stores=Dict(a=>0 for a in LW.IDS)
 for a in LW.IDS;w.inventory[a]=a==A ? 1 : 0;end
 r=LW.food_resources((typed_food=true,initial_inventory_kinds=[a==A ? [6] : Int[] for a in LW.IDS],),w,Any[],Int[],0,stores)
 m=LW.mb_map_state(A)
 candidates()=LW.food_desire_candidates(m,r,A,nothing,80.,true,r.personal[A],[],(0.,0.))
 before=only(filter(c->get(c,"inspect",false),candidates()))
 LW.food_condition_result!(m,6,false,1)
 after=only(filter(c->get(c,"inspect",false),candidates()))
 @test after["priority"]<before["priority"]
 @test before["expected_usable"]==.5 && after["expected_usable"]==0
 @test LW.food_meal_index(r,A,nothing,80.,6)==0
 @test r.inventory[A]==[6] && w.inventory[A]==1 && w.consumed==0
 @test LW.food_audit!(r,w,Int[],0,stores)===nothing
end
