include("animals_only.jl")
@testset "local human scent, decay and movement" begin
    f=HumanScentField();humans=fill((2.,2.),4)
    @test human_scent_gradient(f,0.,2.,0).signal==0
    configured_human_scent_deposit!(f,humans,0)
    @test f.deposits==4
    @test human_scent_gradient(f,0.,2.,0).x<0
    @test human_scent_gradient(f,20.,2.,0).signal==0
    @test human_scent_gradient(f,0.,2.,HUMAN_SCENT.lifetime_ticks).signal==0
    @test 0<human_scent_gradient(f,0.,2.,HUMAN_SCENT.lifetime_ticks÷2).signal<human_scent_gradient(f,0.,2.,0).signal
    @test cos(configured_human_scent_heading(f,0.,2.,0.,0,:predator))>0
    @test cos(configured_human_scent_heading(f,0.,2.,0.,0,:rabbit))>0
    @test configured_human_scent_heading(f,20.,2.,.7,0,:rabbit)==.7
    # No live human position needed after deposition; trail persists, then expires.
    configured_human_scent_deposit!(f,Tuple{Float64,Float64}[],60)
    @test human_scent_gradient(f,0.,2.,60).signal>0
    io=IOBuffer();serialize(io,f);seekstart(io);copy_f=deserialize(io)
    @test human_scent_gradient(copy_f,0.,2.,60)==human_scent_gradient(f,0.,2.,60)
    configured_human_scent_deposit!(copy_f,Tuple{Float64,Float64}[],HUMAN_SCENT.lifetime_ticks)
    @test isempty(copy_f.marks)
    # Camp remains strong without occupants; passing human scent cannot replace it.
    camp_field=HumanScentField(camp=(2.,2.))
    @test human_scent_gradient(camp_field,0.,2.,0).signal>human_scent_gradient(f,0.,2.,0).signal
    @test human_scent_gradient(camp_field,0.,2.,0)==human_scent_gradient(camp_field,0.,2.,17280)
    @test human_scent_gradient(camp_field,20.,2.,0).signal==0
    @test cos(configured_human_scent_heading(camp_field,0.,2.,0.,0,:predator))<0
    @test cos(configured_human_scent_heading(camp_field,0.,2.,0.,0,:rabbit))<0
    io=IOBuffer();serialize(io,camp_field);seekstart(io)
    @test deserialize(io).camp==(2.,2.)
    @test_throws ErrorException HumanScentField(camp=(NaN,2.))
    crowd=HumanScentField()
    configured_human_scent_deposit!(crowd,repeat([(2.,2.),(6.,2.),(2.,6.),(6.,6.)],4),0)
    crowd_gradient=human_scent_gradient(crowd,0.,2.,0)
    @test hypot(crowd_gradient.x,crowd_gradient.z)<=HUMAN_SCENT.trail_gradient_cap+1e-12
    @test cos(configured_human_scent_heading(crowd,0.,2.,0.,0,:predator))>0
    # Existing collision/energy paths still perform the actual predator move.
    s,ps=animal_trial_world();p=ps[1];empty!(s.world.obstacles)
    p.visual.body.x=0.;p.visual.body.z=2.;p.visual.body.heading=0.;p.visual.body.state=P.SEARCH;p.mode=:hunt
    configured_trial_advance!(s,p,0;search_speed=.2,steering=(x,z,h,t)->configured_human_scent_heading(camp_field,x,z,h,t,:predator))
    @test p.visual.body.x<0
    @test p.spent>0
    @test H.clear(s.world,(p.visual.body.x,p.visual.body.z),(p.visual.body.x,p.visual.body.z))
    # Rabbit SEARCH receives the same gradient after its usual target selection.
    s,ps=animal_trial_world();empty!(s.world.obstacles);s.alive.=false;s.alive[1]=true
    s.animals.x[1]=0.;s.animals.z[1]=2.;G.prepare!(s,Tuple{Float64,Float64}[],0)
    s.overrides[1]=H.SEARCH;s.animals.target[1]=H.cell(s.world,2.,2.);s.animals.next_sense[1]=100
    G.advance!(s,0;steering=(w,a,i,speed,overrides)->configured_human_scent_heading(camp_field,a.x[i],a.z[i],a.heading[i],0,:rabbit))
    @test s.animals.x[1]<0
    @test s.alive[1]
end
@testset "disabled bridge preserves animal step" begin
    s,ps=animal_trial_world();other=deepcopy(s);other_ps=deepcopy(ps)
    for tick in 0:99
        animal_trial_step!(s,ps,tick)
        animal_trial_prepare!(other,other_ps,tick)
        animal_trial_advance!(other,other_ps,tick;human_scent=nothing)
    end
    @test animal_trial_report(s,ps)==animal_trial_report(other,other_ps)
end
