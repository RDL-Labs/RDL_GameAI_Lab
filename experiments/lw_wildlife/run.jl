# Fresh integrated run, frozen source, observer-only trajectories and timings.
using JSON3, Test, SHA
length(ARGS)==2 || error("usage: run.jl INPUT.json NEW_OUTPUT")
const original=abspath(ARGS[1]);const out=abspath(ARGS[2])
const repo=normpath(joinpath(@__DIR__,"../.."))
ispath(out) && error("fresh output required")
const input=JSON3.read(read(original,String));const days=Int(input.config.days)
input.scene.wildlife.enabled && 1<=days<=90 || error("enabled wildlife / 1..90 days required")
mkpath(out);const snapshot=joinpath(out,"source");mkpath(joinpath(snapshot,"integrations"))
cp(joinpath(repo,"src"),joinpath(snapshot,"src"))
cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(snapshot,"integrations/lightweight_julia"))
cp(@__FILE__,joinpath(out,"runner.jl"));cp(original,joinpath(out,"input.json"))
write(joinpath(out,"input-origin.json"),JSON3.write((path=original,sha256=bytes2hex(sha256(read(original))))))
const started=Ref(time());const grazing_nanoseconds=Ref(UInt64(0))
const last_wildlife=Ref{Any}(nothing)
const rabbit_trace=open(joinpath(out,"rabbit-trajectory.csv"),"w")
const human_trace=open(joinpath(out,"human-trajectory.csv"),"w")
println(rabbit_trace,"sec,id,x,z,state,alive,energy,gut")
println(human_trace,"sec,actor,x,z,reserve")
function measure_grazing!(f,args...)
    start=time_ns();f(args...);grazing_nanoseconds[]+=time_ns()-start
    nothing
end
function grazing_tick!(s,w,sec)
    last_wildlife[]=s
    if mod(sec+1,60)==0
        a=s.animals
        for i in eachindex(s.alive)
            println(rabbit_trace,join((sec+1,i,a.x[i],a.z[i],a.state[i],Int(s.alive[i]),a.energy[i],a.gut[i]),','))
        end
        for name in IDS
            p=w.positions[name];println(human_trace,join((sec+1,name,p[1],p[2],w.bodies[name].reserve),','))
        end
    end
    if mod(sec+1,17280)==0
        flush(rabbit_trace);flush(human_trace)
        println("DAY $(div(sec+1,17280)) elapsed=$(round(time()-started[],digits=1))s rabbits=$(count(s.alive))/$(length(s.alive)) seen=$(sum(s.seen_ticks)) alert=$(sum(s.alert_entries)) flee=$(sum(s.flee_entries)) grazing=$(round(grazing_nanoseconds[]/1e9,digits=2))s")
        flush(stdout)
    end
end
function patch_saved(anchor,replacement)
    p=joinpath(snapshot,"src/lw/simulation/day.jl");source=read(p,String)
    count(anchor,source)==1 || error("instrumentation anchor changed")
    write(p,replace(source,anchor=>replacement))
end
patch_saved("LWGrazing.prepare!(wildlife,[w.positions[a] for a in IDS],sec)",
    "Main.measure_grazing!(LWGrazing.prepare!,wildlife,[w.positions[a] for a in IDS],sec)")
patch_saved("LWGrazing.advance!(wildlife,sec)","Main.measure_grazing!(LWGrazing.advance!,wildlife,sec)")
patch_saved("        advance_physiology!(w,metabolism,guts,food_body)",
    "        advance_physiology!(w,metabolism,guts,food_body)\n        Main.grazing_tick!(wildlife,w,sec)")
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
started[]=time()
try
    native_main([joinpath(out,"run"),"--spec",joinpath(out,"input.json"),"--checkpoint-dir",joinpath(out,"checkpoints")])
finally
    close(rabbit_trace);close(human_trace)
end
r=JSON3.read(read(joinpath(out,"run/result.json"),String))
summary=JSON3.read(read(joinpath(out,"run/summary.json"),String))
open(joinpath(out,"grass-final.csv"),"w") do io
    w=last_wildlife[].world
    println(io,"x,z,material,capacity,remaining,height,density")
    for k in eachindex(w.grass)
        x,z=LWGrazing.H.center(w,k)
        println(io,join((x,z,w.material[k],w.capacity[k],w.grass[k],w.traits.height[k],w.traits.density[k]),','))
    end
end
@testset "integrated human and grass conservation" begin
    @test length(r.daily)==days
    for (i,d) in enumerate(r.daily)
        @test r.initial_food+d.replenished_food==d.ground+d.shared_stock+d.consumed+sum(s.inventory+s.personal_stock for s in values(d.physical))
        @test d.replenished_food==0
        i>1 && (@test r.day_starts[i]==r.daily[i-1].physical)
        g=d.wildlife
        @test g.ticks==i*17280
        @test g.count==g.alive+g.starvation_deaths
        @test g.grass_initial+g.grass_grown≈g.grass_remaining+g.grass_eaten
        @test all(v->!v.alive || sum(v.state_ticks)==g.ticks,g.final)
    end
end
evidence=(days=days,config=input.config,wildlife_config=input.scene.wildlife,
    measurement=summary.measurement,grazing_update_seconds=grazing_nanoseconds[]/1e9,
    wildlife=r.wildlife,humans=summary.agents,food=summary.food,
    daily=[(day=i,wildlife=d.wildlife,humans=d.physical) for (i,d) in enumerate(r.daily)])
write(joinpath(out,"evidence.json"),JSON3.write(evidence))
write(joinpath(out,"completed.json"),JSON3.write((days=days,alive=r.wildlife.alive)))
println("COMPLETED wildlife=$out")
