include("animals_only.jl")
include("../../src/lw/configured_paths/predator_mb_inheritance.jl")
println("Conditions: one recalled rest candidate; common MB weights; all place memories retained within existing capacity")
@testset "dynamic strongest rest relation" begin
    s,ps=animal_trial_world();p=ps[1];mind=PredatorMind(1)
    predator_remember_place!(mind,p,"rest",1)
    p.visual.body.x+=32
    predator_remember_place!(mind,p,"rest",2)
    @test length(mind.places)==2
    child,_=configured_predator_mb_inherit(mind,LocalHunt(1;probabilistic_capture=true),2,1,3)
    @test length(child.places)==2
    rows=[LW.D("method"=>"visit:a","action"=>:visit_rest,"priority"=>1.),
          LW.D("method"=>"visit:b","action"=>:visit_rest,"priority"=>1.),
          LW.D("method"=>"hunt","action"=>:hunt,"priority"=>1.)]
    a=LW.MethodNode(0,mind.loop.threshold,0);b=LW.MethodNode(0,mind.loop.threshold,0)
    mind.loop.methods["visit:a"]=a;mind.loop.methods["visit:b"]=b
    a.reward=10.
    selected=configured_predator_rest_candidates!(mind,copy(rows))
    @test [c["method"] for c in selected]==["visit:a","hunt"]
    b.reward=100.
    selected=configured_predator_rest_candidates!(mind,copy(rows))
    @test [c["method"] for c in selected]==["visit:b","hunt"]
    b.failure_H_total=10000.
    @test first(configured_predator_rest_candidates!(mind,copy(rows)))["method"]=="visit:a"
    @test length(mind.places)==2
    p.visual.body.x+=32
    candidates=predator_candidates(mind,p,(actor=nothing,distance=Inf),nothing,1)
    @test count(c->c["action"]==:visit_rest,candidates)==1
    @test length(mind.places)==2
end
