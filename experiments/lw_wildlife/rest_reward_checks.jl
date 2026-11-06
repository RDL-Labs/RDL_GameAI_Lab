include("animals_only.jl")
@testset "rest supplies no reward or parent relief" begin
    for (spent,dead) in ((0.,false),(20.,false),(90.,false),(20.,true))
        s,ps=animal_trial_world();p=ps[1];mind=PredatorMind(1)
        rival=(actor=nothing,distance=Inf)
        candidate=only(filter(c->c["action"]==:rest,predator_candidates(mind,p,rival,nothing,1)))
        @test candidate["expected"]==0.
        mind.selected=LW.choose_method!(mind.loop,[candidate],1)
        mind.trial=LW.action_trial(1,"rest","rested",candidate["forecast"])
        mind.start_spent=p.spent;mind.start_eaten=p.eaten
        mind.loop.H=3.;mind.loop.methods["rest"].H=2.
        p.spent+=spent
        predator_mind_close!(mind,p,rival,600;dead)
        event=last(mind.loop.events)
        @test event.actual == -spent/PREDATOR_COGNITION.food_value_scale
        @test event.reward==0. && event.relief==0. && event.method_relief==0.
        @test mind.loop.methods["rest"].reward==0.
        @test mind.loop.H≈3.0+max(0.,spent/PREDATOR_COGNITION.food_value_scale-PREDATOR_COGNITION.tolerance)
        @test mind.trial===nothing && mind.loop.trial===nothing
        @test last(mind.records)["status"]==(dead ? "interrupted" : "achieved")
    end
end
