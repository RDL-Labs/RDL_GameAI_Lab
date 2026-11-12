include("animals_only.jl")
@testset "predator energy forecast" begin
    m=PredatorMind(1)
    @test predator_cost_rate(m,:hunt)*600≈23.616666666666667
    predator_cost_learn!(m,:hunt,600.,24.)
    @test predator_cost_rate(m,:hunt)≈.04
    predator_cost_learn!(m,:hunt,300.,15.)
    @test predator_cost_rate(m,:hunt)≈39/900
    @test predator_cost_rate(m,:visit_food)≈300/17280+.1*.22
    before=copy(m.estimates);predator_cost_learn!(m,:hunt,0.,100.)
    @test m.estimates==before
    s,ps=animal_trial_world();p=ps[1];p.food=300.
    rows=Any[LW.D("action"=>:hunt,"forecast"=>600.,"expected"=>0.),LW.D("action"=>:visit_food,"forecast"=>100.)]
    configured_predator_food_demand!(rows,p,m)
    @test rows[1]["food_demand_forecast"].cost≈26.
    @test rows[2]["food_demand_forecast"].cost≈predator_cost_rate(m,:visit_food)*100+26
    @test rows[1]["expected"]≈(.3*900-26)/900
    io=IOBuffer();serialize(io,m);seekstart(io);restored=deserialize(io)
    @test predator_cost_rate(restored,:hunt)==predator_cost_rate(m,:hunt)
end

