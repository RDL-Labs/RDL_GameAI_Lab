include("animals_only.jl")
@testset "scat traces lifecycle" begin
    state=ScatTraces()
    configured_scat_deposit!(state,1.,1.,0x01,0,85.,85.)
    @test only(configured_scat_observe(state,1.,1.,0)).detail==:fresh
    @test isempty(configured_scat_observe(state,100.,100.,0))
    configured_scat_age!(state,8640)
    @test configured_scat_report(state).fresh==0
    @test only(configured_scat_observe(state,1.,1.,8640)).detail==:coarse
    configured_scat_age!(state,8640+10*17280)
    @test configured_scat_report(state).remaining≈.5
    configured_scat_deposit!(state,1.,1.,0x01,8640+10*17280,85.,85.)
    @test configured_scat_report(state).remaining≈1.5
    io=IOBuffer();serialize(io,state);seekstart(io);copy_state=deserialize(io)
    @test configured_scat_report(copy_state)==configured_scat_report(state)
    configured_scat_age!(state,200*17280)
    configured_scat_age!(state,201*17280)
    @test configured_scat_report(state).remaining==0
    @test state.deposited≈state.faded
    s,ps=animal_trial_world(adult_rabbits=30)
    s.alive[3:end].=false;ps[2].alive=false
    state=ScatTraces();configured_scat_step!(state,s,ps,0)
    @test configured_scat_report(state).fresh==3
    before=configured_scat_report(state);configured_scat_step!(state,s,ps,0)
    @test configured_scat_report(state)==before
    @test_throws ErrorException configured_scat_step!(state,s,ps,-1)
end
# Real animal loop, paired copies; trace generation consumes no simulation RNG.
function trial_scat_run(initial,enabled,days)
    s,ps=deepcopy(initial);state=enabled ? ScatTraces() : nothing
    minds=[PredatorMind(i) for i in eachindex(ps)];physical=PredatorPhysiology.(ps)
    for t in 0:days*17280-1
        animal_trial_prepare!(s,ps,t;minds,physiology=physical)
        animal_trial_advance!(s,ps,t;scat_state=state,minds,physiology=physical)
    end
    (s,ps,state,minds,physical)
end
initial=animal_trial_world(adult_rabbits=30)
trial_scat_run(initial,false,1);trial_scat_run(initial,true,1)
rows=Any[]; outcomes=Any[]
for enabled in (false,true,true,false)
    result=@timed trial_scat_run(initial,enabled,3)
    push!(outcomes,result.value)
    row=(enabled,seconds=result.time,bytes=result.bytes,gc_seconds=result.gctime,
        traces=enabled ? configured_scat_report(result.value[3]) : nothing)
    push!(rows,row);println(JSON3.write(row))
end
@testset "trace sidecar does not change ecology" begin
    function state_bytes(parts)
        io=IOBuffer();serialize(io,parts);take!(io)
    end
    @test all(state_bytes((o[1],o[2],o[4],o[5]))==state_bytes((outcomes[1][1],outcomes[1][2],outcomes[1][4],outcomes[1][5])) for o in outcomes[2:end])
    trace=outcomes[2][3];report=configured_scat_report(trace)
    @test report.deposited≈report.remaining+report.faded
    @test report.fresh<=length(outcomes[2][1].alive)*12+2*3
end
length(ARGS)>0 && write(ARGS[1],JSON3.write(rows))

length(ARGS)>0 && serialize(ARGS[1]*".jls",outcomes[2])
