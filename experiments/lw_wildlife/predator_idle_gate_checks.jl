include("animals_only.jl")
function idle_fixture()
    s,ps=animal_trial_world();p=ps[1];m=PredatorMind(1);b=PredatorPhysiology(p)
    p.food=1800.;b.body=LW.Body(10.,0.,p.food,0.)
    predator_mind_plan!(s,p,[p],m,0;physiology=b)
    (s,p,m,b)
end
function idle_run(enabled,n)
    s,p,m,b=idle_fixture()
    for t in 1:n
        predator_mind_plan!(s,p,[p],m,t;physiology=b,idle_gate=enabled)
        configured_trial_advance!(s,p,t;physiology=b)
    end
    (p,m,b)
end
@testset "idle gate resumes and preserves body" begin
    p,m,b=idle_run(true,600)
    q,old,c=idle_run(false,600)
    @test p.food==q.food
    @test p.spent==q.spent
    @test b.body==c.body
    @test m.completed==0
    @test old.completed>0
    @test m.trial["idle_gate_since"]==0
    io=IOBuffer();serialize(io,m);seekstart(io);restored=deserialize(io)
    @test configured_predator_idle_elapsed!(restored,601)==601
    for reason in (:food,:body,:rival,:dead)
        s,p,m,b=idle_fixture()
        @test configured_predator_idle_hold!(m,p,(actor=nothing,distance=Inf),1,b)
        reason==:food && (p.food=899.)
        reason==:body && (b.body=LW.Body(2.,.5,p.food,0.))
        reason==:dead && (p.alive=false)
        rival=(actor=reason==:rival ? p : nothing,distance=1.)
        @test !configured_predator_idle_hold!(m,p,rival,101,b)
        @test configured_predator_idle_elapsed!(m,101)==101
    end
    s,p,m,b=idle_fixture()
    for t in 1:100
        predator_mind_plan!(s,p,[p],m,t;physiology=b)
    end
    p.food=300.;b.body=LW.Body(10.,0.,p.food,0.)
    predator_mind_plan!(s,p,[p],m,101;physiology=b)
    @test m.completed==1
    @test last(m.records)["elapsed"]==101
end
idle_run(false,100);idle_run(true,100)
for enabled in (false,true,true,false)
    timed=@timed idle_run(enabled,20000)
    println((enabled=enabled,seconds=timed.time,bytes=timed.bytes,completed=timed.value[2].completed))
end
