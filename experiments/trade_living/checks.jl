using Test, JSON3
const D=Dict{String,Any}
include("../../src/lw/configured_paths/trade_living.jl")
@testset "isolated trade living conditions" begin
    @test configured_trade_living_wait(false)===nothing
    first_plan=configured_trade_living_wait(true)
    second_plan=configured_trade_living_wait(true)
    @test first_plan["action"]=="rest"
    @test first_plan["configured_rule"]=="trade_living_wait"
    first_plan["action"]="changed"
    @test second_plan["action"]=="rest"
    experiment=JSON3.read(read(joinpath(@__DIR__,"input.json"),String))
    @test experiment.config.days==10
    @test experiment.config.food=="finite"
    @test isempty(experiment.scene.food)
    @test experiment.scene.configured_trade_living
    @test !experiment.scene.wildlife.enabled
    @test !experiment.scene.configured_fishing_training
    @test !experiment.scene.configured_salted_fish_sample
    @test !experiment.scene.post_return_idle
    for (index,actor) in enumerate(experiment.scene.experimental_actor_ids)
        @test sum(experiment.scene.initial_personal_food_counts[Symbol(actor)])==experiment.scene.initial_personal_stock[index]
    end
end
