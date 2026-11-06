using JSON3, Serialization, Test
include("../../src/lw/LW.jl")
const G=LW.LWGrazing;const H=G.H;const P=G.P
include("../../src/lw/configured_paths/predator_animal_trial.jl")
function animal_trial_world()
    input=JSON3.read(read(joinpath(@__DIR__,"predator_3d_spec.json"),String))
    wildlife=merge((;pairs(input.scene.wildlife)...),(predator_count=0,))
    scene=merge((;pairs(input.scene)...),(positions=Tuple{Float64,Float64}[],wildlife=wildlife))
    s=G.build(scene,input.clock)
    cells=findall(s.world.walkable)
    centers=[H.center(s.world,cells[argmin([hypot(H.center(s.world,k)[1]-x,H.center(s.world,k)[2]-6) for k in cells])]) for x in (-8.,8.)]
    predators=[configured_trial_predator(s,centers[i],20261106+i) for i in 1:2]
    s,predators
end
function animal_trial_step!(s,predators,t)
    for p in predators;configured_trial_plan!(s,p,predators,t);end
    G.prepare!(s,Tuple{Float64,Float64}[],t;additional_predators=[p.visual for p in predators],
        additional_predator_alive=[p.alive for p in predators])
    G.advance!(s,t)
    # Alternate contact resolution order to avoid permanent first-predator privilege.
    for i in (iseven(t) ? eachindex(predators) : reverse(eachindex(predators)))
        configured_trial_advance!(s,predators[i],t)
    end
end
function animal_trial_report(s,predators)
    captures=sum(p.visual.body.captures for p in predators)
    (rabbits=G.snapshot(s;additional_predation_deaths=captures),predators=trial_predator_report.(predators))
end
function main()
    checks_only="--checks-only" in ARGS
    out=checks_only ? joinpath(mktempdir(),"checks") : length(ARGS)>0 ? ARGS[1] : "outputs/animals-only-3d"
    ispath(out) && error("output already exists")
    mkpath(out)
    conditions=(days=3,humans=0,adult_rabbits=30,initial_young=5,predators=2,
        rule=PREDATOR_ANIMAL_TRIAL,fixed="territory centers, visual warning/retreat, instantaneous meals; no predator breeding or combat")
    write(joinpath(out,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions))
    s,predators=animal_trial_world()
    @testset "animal trial boundaries" begin
        @test isempty(s.previous_humans) && s.predator===nothing
        configured_trial_plan!(s,predators[1],[predators[1]],0)
        @test predators[1].mode==:rest
        predators[1].food=100.
        configured_trial_plan!(s,predators[1],[predators[1]],0)
        @test predators[1].mode==:hunt
        s,predators=animal_trial_world()
        empty!(s.world.obstacles);s.world.traits.density.=0.
        p,q=predators
        p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.gaze=0.;p.center=(-10.,6.)
        q.visual.body.x=-8.;q.visual.body.z=6.;q.visual.gaze=pi;q.center=(30.,6.)
        configured_trial_plan!(s,p,predators,0);configured_trial_plan!(s,q,predators,0)
        @test p.mode==:warn # A fed resident still defends its center.
        @test q.mode==:retreat
        p.mode=:hunt;p.visual.body.state=P.ATTACK;p.visual.body.timer=1
        s.animals.x.=-20.;s.animals.z.=20.;s.animals.x[1]=-9.5;s.animals.z[1]=6.
        s.animals.state[1]=H.REST
        for t in 0:100
            p.visual.body.captures>0 && break
            p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.body.heading=0.
            p.visual.body.state=P.ATTACK;p.visual.body.timer=1;p.visual.body.attacks+=1
            configured_trial_advance!(s,p,t)
        end
        @test p.visual.body.captures==1 && p.eaten==900.
        @test p.visual.body.timer==0
        @test trial_predator_report(p).food>1700.
        s,predators=animal_trial_world()
        for t in 0:9999;animal_trial_step!(s,predators,t);end
        io=IOBuffer();serialize(io,(s,predators));seekstart(io);copy_s,copy_p=deserialize(io)
        for t in 10000:19999
            animal_trial_step!(s,predators,t);animal_trial_step!(copy_s,copy_p,t)
        end
        @test animal_trial_report(s,predators)==animal_trial_report(copy_s,copy_p)
    end
    checks_only && return
    s,predators=animal_trial_world();daily=Any[]
    elapsed=@elapsed for t in 0:3*17280-1
        animal_trial_step!(s,predators,t)
        if (t+1)%17280==0
            day=div(t+1,17280);report=animal_trial_report(s,predators)
            push!(daily,(day=day,report=report))
            serialize(joinpath(out,"day-$day.jls"),(s,predators))
            println(JSON3.write((day=day,rabbits=report.rabbits.alive,predators=report.predators)))
        end
    end
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,elapsed_seconds=elapsed,daily=daily)))
    println("COMPLETE seconds=",elapsed)
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
