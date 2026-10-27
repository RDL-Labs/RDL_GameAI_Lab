using Test, JSON3
include("../../integrations/lightweight_julia/native.jl")
@testset "provisional goal arrival" begin
    s=goal_arrival_state();obs=D("forward"=>5.,"right"=>0.)
    goal_arrival_update!(s,obs,"home",.5,0);@test s["mode"]=="search"
    goal_arrival_update!(s,obs,"home",.9,1);@test s["mode"]=="approach"
    goal_arrival_update!(s,nothing,nothing,0.,2);@test s["mode"]=="approach"
    goal_arrival_advance!(s,D("operation"=>"1","forward"=>1.,"right"=>0.,"yaw"=>90.))
    @test s["estimate"]["right"]≈-4
    goal_arrival_update!(s,D("forward"=>50.,"right"=>0.),"home",.9,3)
    @test s["mode"]=="search" && s["rejections"]==1
    goal_arrival_update!(s,obs,"home",1.,4);@test s["mode"]=="search"
    s["cooldown"]=0;goal_arrival_update!(s,obs,"home",1.,5)
    move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
    cs=Any[D("method"=>"side","action"=>"walk","direction"=>4,"priority"=>3.,"question"=>"target_observed"),D("method"=>"scan","action"=>"scan","scan_angle"=>90.,"priority"=>3.,"question"=>"target_observed")]
    goal_arrival_project!(s,cs,move,"home",6)
    @test all(c->c["goal_arrival"],cs)
    @test last(cs)["goal_alignment"]>cs[2]["goal_alignment"]
    loop=BasicLoop("home";probabilistic=true);p0=method_distribution(loop,cs);loop.H=32
    @test method_distribution(loop,cs)≈p0
    @test p0[end]>p0[2]
    s["ticks"]=ceil(Int,s["budget"])+241
    goal_arrival_project!(s,Any[],move,"home",7)
    @test s["mode"]=="search"
    s["cooldown"]=0;goal_arrival_update!(s,obs,"food:1",1.,8)
    goal_arrival_update!(s,nothing,nothing,0.,9;completed=true)
    @test s["mode"]=="search" && s["target"]===nothing
end
@testset "parent question outcome isolation" begin
    g=goal_arrival_state();loop=BasicLoop("home");loop.H=10.
    search=D("actions"=>0)
    s=D("parent_mb"=>mb_parent_state(),"goal_arrival"=>D("home"=>g))
    s["parent_mb"]["active"]["home"]=search
    goal_arrival_update!(g,D("forward"=>5.,"right"=>0.),"home",.8,1)
    mb_parent_arrival_sync!(s,loop,"home",1)
    @test loop.H==0.
    @test s["parent_mb"]["modes"]["home"]["mode"]=="approach"
    mb_parent_arrival_sync!(s,loop,"home",2);@test loop.H==0.
    @test mb_parent_estimate!(s,D(),"home",nothing)["mode"]=="approach"
    loop.H+=2.;g["mode"]="search"
    mb_parent_arrival_sync!(s,loop,"home",3)
    @test loop.H==11.
    @test s["parent_mb"]["active"]["home"]===search
    goal_arrival_update!(g,D("forward"=>5.,"right"=>0.),"home",1.,4)
    mb_parent_arrival_sync!(s,loop,"home",4)
    goal_arrival_update!(g,nothing,nothing,0.,5;completed=true)
    mb_parent_arrival_sync!(s,loop,"home",5)
    @test loop.H==0. # Actual success resolves the saved parent question.
    @test s["parent_mb"]["modes"]["home"]["suspended"]===nothing
    for goal in ("home","food"), local_H in (0.,2.,32.)
        child=goal_arrival_state();parent_loop=BasicLoop(goal);parent_loop.H=10.
        map=D("parent_mb"=>mb_parent_state(),"goal_arrival"=>D(goal=>child))
        goal_arrival_update!(child,D("forward"=>5.,"right"=>0.),goal,1.,1)
        mb_parent_arrival_sync!(map,parent_loop,goal,1)
        @test map["parent_mb"]["modes"][goal]["saved_H"]==10.
        parent_loop.H=local_H;child["H"]=100.;child["mode"]="search"
        mb_parent_arrival_sync!(map,parent_loop,goal,2)
        @test parent_loop.H==11. # Neither local pressure is transferred.
        mb_parent_arrival_sync!(map,parent_loop,goal,3)
        @test parent_loop.H==11. # One failure, once.
    end
    @test goal_result_H(32.,false)==32.
end
input=JSON3.read(read(ARGS[1],String),Dict{String,Any});input["scene"]["goal_arrival"]=true
@testset "arrival rho follows question" begin
    for goal in ("home","food")
        s=goal_arrival_state()
        @test goal_arrival_rho(s,"coarse")=="coarse"
        goal_arrival_update!(s,D("forward"=>5.,"right"=>0.),goal,1.,0)
        @test goal_arrival_rho(s,"coarse")=="fine"
        @test goal_arrival_rho(s,"fine")=="fine"
        @test goal_arrival_rho(s,"off")=="off"
        goal_arrival_update!(s,D("forward"=>50.,"right"=>0.),goal,1.,1)
        @test goal_arrival_rho(s,"coarse")=="coarse"
        s["cooldown"]=0;goal_arrival_update!(s,D("forward"=>5.,"right"=>0.),goal,1.,2)
        goal_arrival_update!(s,nothing,nothing,0.,3;completed=true)
        @test goal_arrival_rho(s,"coarse")=="coarse"
    end
end
input["config"]["days"]=2
input["clock"]["day_us"]=600_000_000
input["clock"]["phase_boundaries_us"]=[1_000_000,400_000_000,500_000_000,600_000_000]
input["clock"]["quiet_night_us"]=550_000_000;input["clock"]["sleep_rest_us"]=50_000_000
spec=JSON3.read(JSON3.write(input))
mktempdir() do dir
    r,_=run_integrated(spec;checkpoint_dir=dir)
    resumed,_=run_integrated(spec;resume_from=joinpath(dir,"day-001.jls"))
    @test r==resumed
    @testset "goal state integration" begin
        for a in IDS
            g=r["mb_map"][a]["goal_arrival"]
            @test g["home"]["entries"]>0
            @test g["food"]["entries"]>0
            @test g["home"]["selected"]+g["food"]["selected"]>0
            @test get(g["home"],"rho_fine_decisions",0)>0
            @test get(g["food"],"rho_fine_decisions",0)>0
            println(a," ",JSON3.write(D(k=>D("entries"=>v["entries"],"selected"=>v["selected"],"rejections"=>v["rejections"]) for (k,v) in g)))
        end
    end
    write("outputs/goal-arrival-short-result.json",JSON3.write(r))
end
