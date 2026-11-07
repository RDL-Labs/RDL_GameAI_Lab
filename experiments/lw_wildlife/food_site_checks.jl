include("pursuit_checks.jl")
@testset "pursuit success is local evidence" begin
    child=PredatorPursuit(1)
    LW.choose_method!(child.loop,[LW.D("method"=>"pursue","question"=>"pursuit_progress","priority"=>1.)],1)
    child.loop.methods["pursue"].H=2.
    child.loop.methods["pursue"].failure_H_total=3.
    child.loop.H=4.
    child.active=(target=1,tick=10,distance=6.,closing=.25)
    configured_pursuit_close!(child,25,"capture_range";distance=2.,opportunity=true)
    @test child.loop.methods["pursue"].H==0
    @test child.loop.H==0
    @test child.loop.methods["pursue"].reward==0
    @test child.loop.methods["pursue"].failure_H_total==3.
end
@testset "food expectation separate from route" begin
    s,ps=animal_trial_world();p=ps[1];mind=PredatorMind(1)
    predator_remember_place!(mind,p,"food",0)
    site=only(keys(mind.places));place=deepcopy(mind.places[site])
    @test predator_food_site_repulsion(mind,site)==0
    predator_food_site_effort!(mind,p;elapsed=599.)
    @test predator_food_site_repulsion(mind,site)==0
    predator_food_site_effort!(mind,p)
    r1=predator_food_site_repulsion(mind,site)
    predator_food_site_effort!(mind,p;elapsed=600.)
    r2=predator_food_site_repulsion(mind,site)
    predator_food_site_effort!(mind,p;elapsed=600.)
    r3=predator_food_site_repulsion(mind,site)
    @test 0<r1<r2<r3
    @test r3-r2>r2-r1>r1
    @test mind.places[site]==place && mind.loop.H==0
    p.visual.body.x+=4
    rival=(actor=nothing,)
    penalized=predator_candidates(mind,p,rival,nothing,1)
    before=only(filter(c->get(c,"site",nothing)==site,penalized))
    u_key=food_site_key(site,"unresolved")
    mind.estimates[u_key]=0.
    unpenalized=predator_candidates(mind,p,rival,nothing,1)
    after=only(filter(c->get(c,"site",nothing)==site,unpenalized))
    @test after["priority"]-before["priority"]≈r3
    @test after["target"]==before["target"] && after["forecast"]==before["forecast"]
    @test only(filter(c->c["action"]==:hunt,penalized))==only(filter(c->c["action"]==:hunt,unpenalized))
    mind.estimates[u_key]=3.
    p.visual.body.x-=4
    predator_food_site_gain!(mind,p,67.5)
    @test predator_food_site_repulsion(mind,site)<r3
    @test mind.estimates[food_site_key(site,"unresolved")]+mind.estimates[food_site_key(site,"effort_ticks")]/600≈2.75
    predator_food_site_gain!(mind,p,1350.)
    @test predator_food_site_repulsion(mind,site)==0
    p.visual.body.x+=100
    predator_food_site_effort!(mind,p;elapsed=600.)
    @test predator_food_site_repulsion(mind,site)==0
    p.visual.body.x-=100
    predator_food_site_effort!(mind,p;elapsed=600000.)
    @test isfinite(predator_food_site_repulsion(mind,site))
    io=IOBuffer();serialize(io,mind);seekstart(io)
    @test predator_mind_report(deserialize(io))==predator_mind_report(mind)
end
