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
input=JSON3.read(read(ARGS[1],String),Dict{String,Any});input["scene"]["goal_arrival"]=true
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
            println(a," ",JSON3.write(D(k=>D("entries"=>v["entries"],"selected"=>v["selected"],"rejections"=>v["rejections"]) for (k,v) in g)))
        end
    end
    write("outputs/goal-arrival-short-result.json",JSON3.write(r))
end
