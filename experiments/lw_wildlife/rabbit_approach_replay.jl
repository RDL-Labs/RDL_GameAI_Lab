# Isolated diagnostic: same saved rabbit/world, other actors and threats paused.
# Usage: RUN OUTPUT.json. Does not resume or overwrite the original simulation.
using JSON3,Serialization,Test
include("animals_only.jl")
root=abspath(ARGS[1]);saved=deserialize(joinpath(root,"checkpoints/day-006.jls"))
source=saved.state[:wildlife];i=25;t=source.ticks;rows=Any[]
println("CONDITIONS ",JSON3.write((rabbit=i,start_day=6,boundary=true,grass="unchanged",other_actors="paused",H_initial=0,ticks=[1000,17280],rule=H.RABBIT_APPROACH)))
for enabled in (false,true)
    s=deepcopy(source);w=s.world;a=s.animals
    @test w.boundary_gradient
    mask=falses(length(s.alive));mask[i]=true
    policy=enabled ? H.RabbitApproachPolicy() : H.StateMachinePolicy()
    start=(energy=a.energy[i],eaten=a.consumed[i],distance=a.distance[i]);samples=Any[];death=nothing
    for dt in 0:17279
        if mask[i]
            H.step!(w,a,t+dt,s.demand,s.ratio,s.requests,s.active;alive=mask,policy)
            if a.energy[i]<=0;mask[i]=false;death=dt+1;end
        end
        if dt+1 in (1000,17280)
            push!(samples,(ticks=dt+1,alive=mask[i],energy=a.energy[i],food=a.consumed[i]-start.eaten,
                distance=a.distance[i]-start.distance,position=(a.x[i],a.z[i])))
        end
    end
    memory=enabled ? policy.actors[i] : nothing
    push!(rows,(enabled=enabled,death_tick=death,samples=samples,H=enabled ? memory.H : nothing,records=enabled ? memory.records : nothing))
    @test isapprox(w.eaten,sum(a.consumed);atol=1e-6)
end
@test rows[1].samples[1].food≈.33567997904583535
@test rows[1].samples[1].distance≈119.2
write(ARGS[2],JSON3.write((conditions="Isolated rabbit 25 from day6, boundary and grass unchanged; no world interactions",rows=rows)))
println(JSON3.write([(enabled=x.enabled,death=x.death_tick,samples=x.samples,H=x.H) for x in rows]))
