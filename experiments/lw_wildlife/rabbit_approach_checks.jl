include("animals_only.jl")
@testset "rabbit approach residual and local evidence" begin
    s,_=animal_trial_world();w=s.world;a=s.animals;i=1
    policy=H.RabbitApproachPolicy();m=H.approach_memory(policy,i)
    a.state[i]=H.SEARCH
    H.target!(w,a,i,0,policy)
    @test m.target>0
    target=m.target;deadline=m.forecast
    H.target!(w,a,i,10,policy)
    @test m.target==target && m.forecast==deadline && m.elapsed==0
    for state in (H.SLEEP,H.REST,H.GRAZE,H.FLEE,H.ALERT)
        a.state[i]=state;H.approach_feedback!(policy,w,a,i,11)
        @test m.elapsed==0 && m.H[target]==0
    end
    a.state[i]=H.SEARCH
    for tick in 1:deadline;H.approach_feedback!(policy,w,a,i,tick);end
    @test m.H[target]>0 && m.target==0
    prior=m.H[target]
    H.target!(w,a,i,100,policy)
    @test m.H[target]==prior # reselection does not erase failure
    # Local arrival changes no food/energy; only that relation's H is resolved.
    m.target=target;m.H[target]=3.;a.x[i],a.z[i]=H.center(w,target)
    before=(a.energy[i],a.consumed[i],a.gut[i])
    H.approach_feedback!(policy,w,a,i,101)
    @test m.H[target]==0 && m.target==0
    @test before==(a.energy[i],a.consumed[i],a.gut[i])
    # Persist both relationship pressure and RNG, not merely selected coordinates.
    m.H[target]=2.
    io=IOBuffer();serialize(io,policy);seekstart(io);restored=deserialize(io)
    @test restored.actors[i].H==m.H
    @test rand(restored.actors[i].rng)==rand(m.rng)
end
