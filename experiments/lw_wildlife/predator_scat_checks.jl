include("animals_only.jl")
@testset "predator scat evidence" begin
    s,ps=animal_trial_world();p=ps[1];p.mode=:hunt;p.visual.body.state=P.SEARCH
    traces=ScatTraces();scent=PreyScentWorld(length(ps);cautious=true)
    x=p.visual.body.x;z=p.visual.body.z
    configured_scat_deposit!(traces,x+3,z,0x01,0,85.,85.)
    cue=configured_predator_scat_cue(traces,scent,p,1,0,PREY_SCENT.minimum_signal)
    @test cue.source==:scat && cue.target==(x+3,z)
    @test !hasproperty(cue,:id)
    @test configured_predator_scat_cue(traces,scent,p,1,0,cue.signal)===nothing
    scent.cooldown[1][prey_scent_cell(x+3,z)]=100
    @test configured_predator_scat_cue(traces,scent,p,1,0,0.)===nothing
    empty!(scent.cooldown[1])
    old=configured_predator_scat_cue(traces,scent,p,1,8640,0.)
    @test old===nothing || old.signal<cue.signal
    # Suppress live body odor: all prey may have left/died, the trace remains.
    s.alive.=false
    configured_prey_scent_tick!(scent,s,ps,0;scat_state=traces)
    @test scent.observed[1].source==:scat
    configured_prey_scent_steer!(scent,p,1,0)
    @test p.visual.body.heading≈0.
    @test scent.steering_ticks==1
    p.mode=:idle
    configured_prey_scent_tick!(scent,s,ps,30;scat_state=traces)
    @test scent.observed[1]===nothing
    p.mode=:hunt;p.visual.body.state=P.CHASE
    configured_prey_scent_tick!(scent,s,ps,60;scat_state=traces)
    @test scent.observed[1]===nothing
    other=ScatTraces();configured_scat_deposit!(other,x+3,z,0x02,0,900.,900.)
    @test configured_predator_scat_cue(other,scent,p,1,0,0.)===nothing
end
function scat_hunt_trial()
    s,ps=animal_trial_world();traces=ScatTraces();scent=PreyScentWorld(length(ps);cautious=true)
    minds=[PredatorMind(i) for i in eachindex(ps)];physical=PredatorPhysiology.(ps)
    selected=0
    for t in 0:3*17280-1
        animal_trial_prepare!(s,ps,t;minds,physiology=physical,prey_scents=scent,scat_state=traces)
        if t%PREY_SCENT.sniff_interval==0
            selected+=count(o->o!==nothing && hasproperty(o,:source) && o.source==:scat,scent.observed)
        end
        animal_trial_advance!(s,ps,t;minds,physiology=physical,prey_scents=scent,scat_state=traces)
    end
    (selected=selected,scents=prey_scent_report(scent),captures=[p.visual.body.captures for p in ps],traces=configured_scat_report(traces))
end
result=@timed scat_hunt_trial()
println(JSON3.write((seconds=result.time,result=result.value)))
@test result.value.selected>0
length(ARGS)>0 && write(ARGS[1],JSON3.write((seconds=result.time,result=result.value)))
