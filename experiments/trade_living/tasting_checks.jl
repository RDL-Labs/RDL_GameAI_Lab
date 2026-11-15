include("supply_checks.jl")
@testset "training requires actual taste evidence" begin
    maps=Dict(a=>LW.D() for a in LW.IDS)
    actor=first(LW.IDS);food=(inventory=Dict(actor=>Int[]),)
    @test LW.configured_tasting_plan(maps[actor],food,actor,true,true,0)["action"]=="retrieve"
    push!(food.inventory[actor],1)
    @test LW.configured_tasting_plan(maps[actor],food,actor,false,true,0)["action"]=="rest"
    @test LW.configured_tasting_plan(maps[actor],food,actor,true,true,0)["action"]=="eat"
    @test_throws ErrorException LW.configured_tasting_ready!(maps,3,100)
    for a in LW.IDS, kind in (1,4,8)
        LW.food_remember_taste!(maps[a],kind,2,.4,10)
    end
    @test LW.configured_tasting_plan(maps[actor],food,actor,true,true,0)["action"]=="rest"
    @test LW.configured_tasting_plan(maps[actor],food,actor,true,true,3)===nothing
    LW.configured_tasting_ready!(maps,3,100)
    LW.configured_tasting_ready!(maps,4,200)
    @test maps[actor]["tasting_training"]["completed_us"]==100
    supply=Dict(actor=>Dict("kind"=>3,"quantity"=>2))
    @test LW.configured_tasting_supply(supply,2)[actor]["kind"]==8
    @test LW.configured_tasting_supply(supply,3)===supply
end
