using Test, Serialization
include("../../src/lw/LW.jl")
@testset "personal supply conservation and restart" begin
    w=LW.world(true);stores=Dict(a=>0 for a in LW.IDS)
    for a in LW.IDS;w.inventory[a]=0;end
    food=LW.food_resources((typed_food=true,food_batch_expiry=true,),w,Any[],Int[],0,stores)
    actor=first(LW.IDS);ledger=Any[]
    supply=Dict(actor=>Dict("kind"=>8,"quantity"=>2))
    @test LW.configured_personal_food_supply!(food,stores,ledger,nothing,0,0)==0
    @test LW.configured_personal_food_supply!(food,stores,ledger,supply,0,0)==2
    @test food.personal[actor][8]==2 && stores[actor]==2
    @test LW.food_audit!(food,w,Int[],0,stores)===nothing
    @test LW.food_age_audit!(food)===nothing
    @test LW.configured_personal_food_supply!(food,stores,ledger,supply,0,0)==0
    io=IOBuffer();serialize(io,(food,stores,ledger));seekstart(io)
    food,stores,ledger=deserialize(io)
    @test LW.configured_personal_food_supply!(food,stores,ledger,supply,0,0)==0
    LW.food_expire_batches!(food,Any[],Int[],0,1)
    @test food.personal[actor][8]==0 && food.personal[actor][6]==2
    @test LW.configured_personal_food_supply!(food,stores,ledger,supply,1,17280000000)==2
    @test last(ledger)["deadline"]==2
    @test stores[actor]==4 && sum(food.added)==4
    @test LW.food_audit!(food,w,Int[],0,stores)===nothing
    @test LW.food_age_audit!(food)===nothing
    @test_throws ErrorException LW.configured_personal_food_supply!(food,stores,ledger,supply,2,0;shared_stores=true)
    @test_throws ErrorException LW.configured_personal_food_supply!(food,stores,ledger,Dict(actor=>Dict("kind"=>8,"quantity"=>-1)),2,0)
end
