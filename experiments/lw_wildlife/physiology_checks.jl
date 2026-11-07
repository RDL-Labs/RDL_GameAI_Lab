include("animals_only.jl")
@testset "shared body and actual recovery" begin
    s,ps=animal_trial_world();p=ps[1];body=PredatorPhysiology(p);mind=PredatorMind(1)
    rival=(actor=nothing,distance=Inf)
    @test !any(c->c["action"]==:rest,predator_candidates(mind,p,rival,nothing,1;physiology=body))
    body.body=LW.Body(2.,.5,p.food,0.)
    candidate=only(filter(c->c["action"]==:rest,predator_candidates(mind,p,rival,nothing,1;physiology=body)))
    @test 1<=candidate["forecast"]<600
    @test candidate["expected"]>0
    mind.selected=LW.choose_method!(mind.loop,[candidate],1)
    mind.selected["body_start_need"]=predator_recovery_need(body.body)
    mind.trial=LW.action_trial(1,"rest","rested",candidate["forecast"])
    mind.start_food=p.food;mind.start_spent=p.spent
    p.mode=:rest
    initial_need=predator_recovery_need(body.body);initial_food=p.food
    for t in 1:Int(candidate["forecast"])
        configured_trial_advance!(s,p,t;physiology=body)
    end
    @test predator_recovery_need(body.body)<initial_need
    @test p.food<initial_food && body.body.reserve==p.food
    @test isapprox(initial_food-p.food,p.spent;atol=1e-8)
    predator_mind_close!(mind,p,rival,200;physiology=body)
    @test last(mind.records)["actual"]>0
    @test mind.loop.methods["rest"].reward>0
    # Activity carries real fatigue, movement geometry remains the predator's.
    body.body=LW.Body(10.,0.,p.food,0.);p.mode=:hunt;p.visual.body.state=P.SEARCH
    before=p.visual.body.distance
    configured_trial_advance!(s,p,201;physiology=body)
    @test body.body.strain≈(p.visual.body.distance-before)*PREDATOR_BODY.move_strain
    @test body.body.reserve==p.food
    # Exhaustion blocks movement; rest restores capability without creating food.
    body.body=LW.Body(0.,1.,p.food,0.);before=p.visual.body.distance
    configured_trial_advance!(s,p,202;physiology=body)
    @test p.visual.body.distance==before
    @test body.limited_ticks==1
    p.mode=:rest;configured_trial_advance!(s,p,203;physiology=body)
    @test body.body.strain<1 && body.body.burst>0
    empty_body=LW.Body(0.,.5,0.,0.)
    @test predator_recover(empty_body)==empty_body
    # Serialization preserves full sidecar state, old predator/mind layout unchanged.
    io=IOBuffer();serialize(io,(p,body));seekstart(io);p2,b2=deserialize(io)
    @test b2.body.reserve==p2.food && b2.body==body.body
    @test trial_predator_report(p).balance_residual≈0 atol=1e-7
end
@testset "rest completion and hunger reconsideration" begin
    for reason in ("recovered","hunger_changed")
        s,ps=animal_trial_world();p=ps[1];mind=PredatorMind(1);physical=PredatorPhysiology(p)
        physical.body=LW.Body(2.,.5,p.food,0.)
        c=only(filter(c->c["action"]==:rest,predator_candidates(mind,p,(actor=nothing,distance=Inf),nothing,1;physiology=physical)))
        mind.selected=LW.choose_method!(mind.loop,[c],1)
        mind.selected["body_start_need"]=predator_recovery_need(physical.body)
        mind.trial=LW.action_trial(1,"rest","rested",c["forecast"])
        mind.start_food=p.food;mind.start_spent=p.spent
        if reason=="recovered"
            physical.body=LW.Body(10.,0.,p.food,0.)
        else
            p.food-=20;p.spent+=20;physical.body=LW.Body(2.,.5,p.food,0.)
        end
        predator_mind_plan!(s,p,[p],mind,1;physiology=physical)
        @test last(mind.records)["body_end_reason"]==reason
        @test last(mind.records)["elapsed"]<c["forecast"]
    end
end
