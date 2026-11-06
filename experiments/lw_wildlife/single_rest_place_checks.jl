include("animals_only.jl")
include("../../src/lw/configured_paths/predator_mb_inheritance.jl")
println("Conditions: single_rest_place=true; first rest site retained; legacy sites ranked by experience")
@testset "single predator rest place" begin
    s,ps=animal_trial_world();p=ps[1];mind=PredatorMind(1)
    predator_remember_place!(mind,p,"rest",1)
    rest_key=only(keys(mind.places));rest_place=mind.places[rest_key]
    predator_remember_place!(mind,p,"rest",2)
    @test mind.places[rest_key].successes==2
    p.visual.body.x+=32
    predator_remember_place!(mind,p,"rest",3)
    @test length(mind.places)==1
    @test mind.places[rest_key].x==rest_place.x
    for tick in 4:30
        p.visual.body.x+=16
        predator_remember_place!(mind,p,"food",tick)
    end
    @test haskey(mind.places,rest_key)
    @test length(mind.places)==PREDATOR_COGNITION.place_limit
    mind.places["rest:legacy"]=(kind="rest",x=0.,z=0.,seen=31,successes=10)
    food_before=Dict(k=>v for (k,v) in mind.places if v.kind=="food")
    rows=predator_candidates(mind,p,(actor=nothing,distance=Inf),nothing,1)
    @test count(c->c["action"]==:visit_rest,rows)==1
    @test haskey(mind.places,"rest:legacy")
    @test !haskey(mind.places,rest_key)
    @test food_before==Dict(k=>v for (k,v) in mind.places if v.kind=="food")
    mind.places[rest_key]=rest_place
    child,_=configured_predator_mb_inherit(mind,LocalHunt(1;probabilistic_capture=true),2,1,32)
    @test count(v->v.kind=="rest",values(child.places))==1
    @test count(v->v.kind=="rest",values(mind.places))==2
end
