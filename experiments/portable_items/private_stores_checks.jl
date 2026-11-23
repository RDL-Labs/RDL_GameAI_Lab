include("checks.jl")
@testset "private warehouses preserve explicit proposals" begin
    f=barter_fixture()
    hidden=item_view(f,ITEM_A)
    @test !haskey(hidden,"observed_food_stocks")
    @test !haskey(hidden,"observed_food_conditions")
    @test !any(r->r["ref"]==2,hidden["visible"])
    # Unknown is not an observation of zero or an invented stock.
    @test LW.observed_food_count(hidden,ITEM_B,1)===nothing
    @test LW.observed_food_candidate_count(hidden,ITEM_B,1)==0
    offer_item(f;give_food=[1,0,0,0])
    recipient=item_view(f,ITEM_B;now=1)
    @test length(recipient["incoming"])==1
    @test only(recipient["incoming"])["give_food"][1]==1
    @test LW.observed_food_count(recipient,ITEM_A,1)==1
    @test LW.observed_food_count(recipient,ITEM_A,2)===nothing
    @test !haskey(recipient,"observed_food_stocks")
end
